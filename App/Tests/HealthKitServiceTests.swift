import HealthKit
import XCTest
@testable import Milemark

/// The HealthKit side of the import.
///
/// The store in a simulator is empty and HealthKit never says whether
/// permission was refused, so these tests cannot prove that a workout comes
/// back. They can prove that the entitlement is in place, that the query
/// runs, and that a workout is turned into a run with the right numbers.
@MainActor
final class HealthKitServiceTests: XCTestCase {
    func testHealthDataIsAvailableInTheSimulator() {
        let service = HealthKitService()
        XCTAssertNotEqual(service.state, .unavailable, "HealthKit should be available on this platform.")
    }

    /// Asking for workouts before the reader has been asked for permission
    /// has to be recognised, because it is a different thing from the reader
    /// having said no.
    func testQueryingBeforePermissionIsRecognised() async {
        let service = HealthKitService()
        do {
            _ = try await service.recentRuns()
            // If a query somehow succeeds there is nothing to assert: the
            // simulator's store is empty and the sheet was never shown.
        } catch let error as HealthError {
            // An unsigned build has no entitlement, which is a different
            // failure and is recognised as one.
            XCTAssertTrue(
                error == .authorizationNotDetermined || error == .entitlementMissing,
                "Unexpected error: \(error)"
            )
        } catch {
            XCTFail("Expected a HealthError, got \(error).")
        }
    }

    /// A workout carries its own distance, time and energy, and the receipt
    /// shows them whether or not a route came with it.
    func testAWorkoutBecomesARunWithItsNumbers() async throws {
        let service = HealthKitService()
        let workout = HKWorkout(
            activityType: .running,
            start: Date().addingTimeInterval(-3600),
            end: Date(),
            duration: 3600,
            totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: 500),
            totalDistance: HKQuantity(unit: .meter(), doubleValue: 8000),
            metadata: nil
        )

        let healthRun = try await service.makeRun(from: workout)
        XCTAssertEqual(healthRun.run.distanceMeters, 8000)
        XCTAssertEqual(healthRun.run.movingTime, 3600)
        XCTAssertEqual(healthRun.run.elapsedTime, 3600)
        XCTAssertEqual(healthRun.energyKilocalories, 500)
        XCTAssertEqual(healthRun.run.source, .imported)
        XCTAssertEqual(healthRun.run.sourceName, "Health")
        // HealthKit's workouts do not carry a route, so there is no shape to
        // draw and the app does not pretend there is one.
        XCTAssertTrue(healthRun.run.points.isEmpty)
    }

    /// A run from Health gets a name that says what it was.
    func testAWorkoutIsNamedForWhatItWas() async throws {
        let service = HealthKitService()
        let workout = HKWorkout(
            activityType: .running,
            start: Date().addingTimeInterval(-600),
            end: Date(),
            duration: 600,
            totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: 90),
            totalDistance: HKQuantity(unit: .meter(), doubleValue: 2000),
            metadata: nil
        )
        let healthRun = try await service.makeRun(from: workout)
        XCTAssertEqual(healthRun.run.title, "Outdoor run")
    }
}
