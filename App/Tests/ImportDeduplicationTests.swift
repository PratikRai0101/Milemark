import XCTest
@testable import Milemark

/// Importing the same activity twice must not produce two copies of it.
@MainActor
final class ImportDeduplicationTests: XCTestCase {
    private func makeRun(sourceID: String, title: String = "Morning Run", date: Date = Date()) -> Run {
        Run(
            title: title,
            startedAt: date,
            endedAt: date.addingTimeInterval(600),
            elapsedTime: 600,
            movingTime: 600,
            distanceMeters: 5000,
            elevationGainMeters: 0,
            points: [],
            source: .imported,
            sourceID: sourceID,
            sourceName: "Strava"
        )
    }

    func testImportingTheSameActivityTwiceAddsOneRun() throws {
        let store = RunStore(fileURL: URL(fileURLWithPath: "/tmp/milemark-import-test-\(UUID().uuidString).json"))
        defer { try? FileManager.default.removeItem(at: store.fileURL) }

        let first = store.importRuns([makeRun(sourceID: "1")])
        XCTAssertEqual(first.added, 1)
        XCTAssertTrue(first.saved)

        let second = store.importRuns([makeRun(sourceID: "1")])
        XCTAssertEqual(second.added, 0)
        XCTAssertEqual(store.runs.count, 1)
    }

    /// Two runs of the same loop on the same day are two runs.
    func testDifferentActivitiesAreBothImported() throws {
        let store = RunStore(fileURL: URL(fileURLWithPath: "/tmp/milemark-import-test-\(UUID().uuidString).json"))
        defer { try? FileManager.default.removeItem(at: store.fileURL) }

        store.importRuns([makeRun(sourceID: "1")])
        store.importRuns([makeRun(sourceID: "2")])
        XCTAssertEqual(store.runs.count, 2)
    }

    /// A run recorded on this phone is never treated as an import.
    func testARecordedRunIsNotAnImport() throws {
        let store = RunStore(fileURL: URL(fileURLWithPath: "/tmp/milemark-import-test-\(UUID().uuidString).json"))
        defer { try? FileManager.default.removeItem(at: store.fileURL) }

        var recorded = makeRun(sourceID: "1")
        recorded.source = .recorded
        store.add(recorded)

        let result = store.importRuns([makeRun(sourceID: "1")])
        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(store.runs.count, 2)
    }

    func testTheStoreKnowsWhatItAlreadyHas() throws {
        let store = RunStore(fileURL: URL(fileURLWithPath: "/tmp/milemark-import-test-\(UUID().uuidString).json"))
        defer { try? FileManager.default.removeItem(at: store.fileURL) }

        store.importRuns([makeRun(sourceID: "abc")])
        XCTAssertTrue(store.hasImported(source: .imported, sourceID: "abc"))
        XCTAssertFalse(store.hasImported(source: .imported, sourceID: "xyz"))
    }
}
