import Foundation
import Observation

/// Stores finished runs and the collection state on disk.
///
/// Runs are persisted as JSON in Application Support. Nothing leaves the
/// device: there is no account, no server and no third-party import in this
/// version of the app.
@MainActor
@Observable
public final class RunStore {
    public private(set) var runs: [Run] = []
    public private(set) var lastError: String?

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL? = nil) {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL.temporaryDirectory
        let directory = base.appending(path: "Milemark", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = fileURL ?? directory.appending(path: "runs.json")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        load()

        // Launching with -seedDemoData gives screenshots and UI checks
        // something to look at without needing a recorded run.
        if ProcessInfo.processInfo.arguments.contains("-seedDemoData") {
            runs = DemoActivity.all()
            save()
        }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            runs = try decoder.decode([Run].self, from: data).sorted { $0.startedAt > $1.startedAt }
        } catch {
            lastError = "Saved runs could not be read: \(error.localizedDescription)"
            runs = []
        }
    }

    public func save() {
        do {
            let data = try encoder.encode(runs)
            try data.write(to: fileURL, options: .atomic)
            lastError = nil
        } catch {
            lastError = "Runs could not be saved: \(error.localizedDescription)"
        }
    }

    // MARK: - Collection

    public func add(_ run: Run) {
        runs.removeAll { $0.id == run.id }
        runs.append(run)
        runs.sort { $0.startedAt > $1.startedAt }
        save()
    }

    public func update(_ run: Run) {
        guard let index = runs.firstIndex(where: { $0.id == run.id }) else { return }
        runs[index] = run
        save()
    }

    public func setCollected(_ collected: Bool, for runID: UUID) {
        guard let index = runs.firstIndex(where: { $0.id == runID }) else { return }
        runs[index].isCollected = collected
        save()
    }

    public func delete(runID: UUID) {
        runs.removeAll { $0.id == runID }
        save()
    }

    /// Loads the sample activities, replacing anything already stored.
    public func loadSampleActivities() {
        runs = DemoActivity.all()
        save()
    }

    public func run(id: UUID) -> Run? {
        runs.first { $0.id == id }
    }

    /// Runs that start on the same date, newest first.
    public func runs(on date: Date) -> [Run] {
        runs.filter { Calendar.current.isDate($0.startedAt, inSameDayAs: date) }
    }

    /// Total distance for the current year, in kilometres.
    public var yearDistanceKilometres: Double {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: .now)
        return runs
            .filter { calendar.component(.year, from: $0.startedAt) == year }
            .reduce(0) { $0 + $1.distanceMeters }
            / 1000
    }
}
