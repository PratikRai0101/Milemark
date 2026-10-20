import Foundation
import HealthKit
import Observation

/// Reads runs that the system already knows about.
///
/// HealthKit holds the workouts recorded by the system's own training apps,
/// and the heart rate inside them. Milemark does not write to it: it only
/// asks to read, and it asks for the narrowest set of things that would let
/// it print a receipt.
///
/// The reader is asked for permission in a system sheet. If they say no,
/// the app says so and carries on without it.
@MainActor
@Observable
public final class HealthKitService {
    /// What the app knows about the permission.
    public enum State: Equatable {
        /// This device cannot keep health data, so there is nothing to read.
        case unavailable
        /// Permission has not been asked for yet.
        case notAsked
        /// The reader has not been asked yet, or has not answered.
        case notDetermined
        /// The reader allowed the app to read.
        case authorised
        /// The reader said no, or only allowed part of it.
        case refused
        /// Something went wrong.
        case failed(String)
    }

    public private(set) var state: State

    private let store = HKHealthStore()

    public init() {
        state = HKHealthStore.isHealthDataAvailable() ? .notDetermined : .unavailable
    }

    /// The kinds of data the app would like to read.
    ///
    /// Nothing is written, so the list of types to share is empty.
    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(energy)
        }
        if let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }
        return types
    }

    /// Asks the reader for permission.
    ///
    /// HealthKit does not say whether permission was granted: it deliberately
    /// does not, so that an app cannot learn what a person refuses to
    /// share. The app therefore checks what it can actually read afterwards,
    /// rather than trusting the sheet's answer.
    public func requestAuthorisation() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            state = .unavailable
            return
        }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            state = .authorised
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// The recent running workouts, newest first.
    public func recentRuns(since days: Int = 90, limit: Int = 50) async throws -> [HealthRun] {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthError.unavailable }

        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: Date(),
            options: [.strictStartDate]
        )

        let workouts = try await loadWorkouts(predicate: predicate, limit: limit)
        var runs: [HealthRun] = []
        for workout in workouts {
            runs.append(try await makeRun(from: workout))
        }
        return runs
    }

    // MARK: - Queries

    private func loadWorkouts(predicate: NSPredicate, limit: Int) async throws -> [HKWorkout] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: limit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts)
            }
            store.execute(query)
        }
    }

    /// The heart rate samples inside a workout, averaged.
    private func averageHeartRate(in workout: HKWorkout) async throws -> Int? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }

        let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKQuantitySample], Error>) in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: HKQuery.predicateForSamples(
                    withStart: workout.startDate,
                    end: workout.endDate,
                    options: [.strictStartDate]
                ),
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let quantities = (samples as? [HKQuantitySample]) ?? []
                continuation.resume(returning: quantities)
            }
            store.execute(query)
        }

        guard !samples.isEmpty else { return nil }
        let unit = HKUnit.count().unitDivided(by: .minute())
        let total = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: unit) }
        return Int((total / Double(samples.count)).rounded())
    }

    /// Builds a run from a workout.
    private func makeRun(from workout: HKWorkout) async throws -> HealthRun {
        let heartRate = try await averageHeartRate(in: workout)
        let distance = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
        let energy = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0

        let run = Run(
            title: Self.title(for: workout),
            note: "",
            startedAt: workout.startDate,
            endedAt: workout.endDate,
            elapsedTime: workout.duration,
            movingTime: workout.duration,
            distanceMeters: distance,
            elevationGainMeters: 0,
            averageHeartRate: heartRate,
            // HealthKit's workouts do not carry a route, so the receipt shows
            // the numbers without a drawn shape. Saying so is better than
            // drawing a straight line and calling it a route.
            points: [],
            source: .imported,
            sourceID: workout.uuid.uuidString,
            sourceName: "Health"
        )

        return HealthRun(run: run, energyKilocalories: energy)
    }

    /// A name for the run, taken from the workout's metadata when it has one.
    private static func title(for workout: HKWorkout) -> String {
        if let name = workout.metadata?[HKMetadataKeyWorkoutBrandName] as? String, !name.isEmpty {
            return name
        }
        switch workout.workoutActivityType {
        case .running: return "Outdoor run"
        case .walking: return "Walk"
        case .cycling: return "Ride"
        case .hiking: return "Hike"
        case .swimming: return "Swim"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Strength session"
        case .yoga: return "Yoga"
        case .highIntensityIntervalTraining: return "Intervals"
        case .elliptical: return "Elliptical"
        case .rowing: return "Row"
        default: return "Workout"
        }
    }
}

/// A workout from HealthKit, with the energy it burned.
public struct HealthRun: Sendable, Identifiable {
    public var run: Run
    public var energyKilocalories: Double

    public var id: UUID { run.id }
}

/// What can go wrong when reading from HealthKit.
enum HealthError: LocalizedError {
    case unavailable

    var message: String {
        switch self {
        case .unavailable:
            "This device does not keep health data."
        }
    }
}
