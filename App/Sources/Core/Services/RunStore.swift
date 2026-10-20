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
    /// Whether the runs file could not be read or set aside.
    public private(set) var isUnreadable = false

    /// Where the runs are kept. Exposed so that a test can use a file of its
    /// own rather than the one the app is using.
    let fileURL: URL
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
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            runs = try decoder.decode([Run].self, from: data).sorted { $0.startedAt > $1.startedAt }
        } catch {
            // The file is unreadable. It is moved aside rather than
            // overwritten, so nothing is lost and the next save can start
            // from a clean file.
            lastError = "Saved runs could not be read: \(error.localizedDescription)"
            quarantine()
            runs = []
        }
    }

    /// Moves an unreadable file aside so it is never overwritten.
    private func quarantine() {
        let stamp = ISO8601DateFormatter().string(from: .now)
            .replacingOccurrences(of: ":", with: "-")
        let destination = fileURL
            .deletingLastPathComponent()
            .appending(path: "runs-unreadable-\(stamp).json")
        do {
            try FileManager.default.moveItem(at: fileURL, to: destination)
        } catch {
            // If the file could not be moved, it must not be overwritten.
            lastError = "Saved runs could not be read and could not be set aside: \(error.localizedDescription)"
            isUnreadable = true
        }
    }

    /// Writes the archive.
    ///
    /// It reports whether the write succeeded, so a caller can keep the run
    /// it was trying to save rather than losing it silently.
    @discardableResult
    public func save() -> Bool {
        do {
            let data = try encoder.encode(runs)
            try data.write(to: fileURL, options: .atomic)
            lastError = nil
            return true
        } catch {
            lastError = "Runs could not be saved: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Collection

    /// Adds a run and saves the archive.
    ///
    /// It reports whether the run reached the disk.
    @discardableResult
    public func add(_ run: Run) -> Bool {
        let previous = runs
        runs.removeAll { $0.id == run.id }
        runs.append(run)
        runs.sort { $0.startedAt > $1.startedAt }
        guard save() else {
            // A run that did not reach the disk is not a saved run.
            runs = previous
            return false
        }
        return true
    }

    public func update(_ run: Run) {
        guard let index = runs.firstIndex(where: { $0.id == run.id }) else { return }
        runs[index] = run
        save()
    }

    /// Whether a run from another service is already in the archive.
    ///
    /// The source's own identifier decides this, not the date or the title:
    /// somebody can run the same loop twice, and the second run is not the
    /// first one.
    public func hasImported(source: Run.Source, sourceID: String) -> Bool {
        runs.contains { $0.source == source && $0.sourceID == sourceID }
    }

    /// Adds runs that came from another service.
    ///
    /// A run that is already here is left alone, so importing the same
    /// activity twice does not produce two copies of it.
    ///
    /// It reports how many were added, and whether they reached the disk.
    @discardableResult
    public func importRuns(_ newRuns: [Run]) -> (added: Int, saved: Bool) {
        let previous = runs
        var added = 0
        for run in newRuns {
            if let sourceID = run.sourceID, hasImported(source: run.source, sourceID: sourceID) {
                continue
            }
            runs.append(run)
            added += 1
        }
        guard added > 0 else { return (0, true) }
        runs.sort { $0.startedAt > $1.startedAt }
        guard save() else {
            // A run that did not reach the disk is not a saved run.
            runs = previous
            return (added, false)
        }
        return (added, true)
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

    /// The most recent earlier run of the same route.
    ///
    /// Two runs count as the same route when their shapes match closely
    /// enough, however different the number of GPS samples in each. The
    /// distance has to be plausible too, or the same shape run somewhere
    /// else would count as the same route.
    public func similarRun(to run: Run, above similarity: Double = 0.9) -> Run? {
        let candidates = runs.filter { $0.id != run.id && $0.startedAt < run.startedAt }
        return candidates
            .filter { candidate in
                guard candidate.distanceMeters > 0, run.distanceMeters > 0 else { return false }
                // The distance has to be plausible.
                let difference = abs(candidate.distanceMeters - run.distanceMeters)
                guard difference / candidate.distanceMeters < 0.3 else { return false }
                // And it has to be the same place. The shape alone cannot say
                // that: the same block run in another city has the same shape.
                return RouteGeometry.startsNear(candidate.points, run.points)
            }
            .map { candidate in
                (candidate, RouteGeometry.similarity(candidate.points, run.points))
            }
            .filter { $0.1 >= similarity }
            .max { $0.0.startedAt < $1.0.startedAt }?
            .0
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
