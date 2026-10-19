import XCTest
@testable import Milemark

/// Tests for the recorder's decisions, which are the ones that change a
/// number on the receipt.
@MainActor
final class RunRecorderTests: XCTestCase {
    /// Builds a recorder and feeds it samples directly.
    private func recorder() -> RunRecorder {
        RunRecorder()
    }

    func testRunStartsEmpty() {
        let recorder = recorder()
        recorder.prepare()
        XCTAssertEqual(recorder.phase, .ready)
        XCTAssertEqual(recorder.distanceMeters, 0)
        XCTAssertEqual(recorder.points.count, 0)
    }

    func testDistanceAccumulatesAlongARoute() {
        let recorder = recorder()
        recorder.prepare()
        recorder.start()

        let start = Date()
        for index in 0..<10 {
            let point = RoutePoint(
                latitude: 1.3000 + Double(index) * 0.0001,
                longitude: 103.8700,
                altitude: 0,
                timestamp: start.addingTimeInterval(Double(index) * 2),
                horizontalAccuracy: 5,
                speed: 3
            )
            recorder.ingest([point])
        }

        // Ten samples about 11 m apart is roughly 100 m of running.
        XCTAssertGreaterThan(recorder.distanceMeters, 90)
        XCTAssertLessThan(recorder.distanceMeters, 130)
        XCTAssertEqual(recorder.points.count, 10)
    }

    func testStandingStillDoesNotAddDistance() {
        let recorder = recorder()
        recorder.prepare()
        recorder.start()

        let start = Date()
        for index in 0..<20 {
            let point = RoutePoint(
                latitude: 1.3000 + (index % 2 == 0 ? 0 : 0.000001),
                longitude: 103.8700,
                altitude: 0,
                timestamp: start.addingTimeInterval(Double(index)),
                horizontalAccuracy: 5,
                speed: 0
            )
            recorder.ingest([point])
        }

        XCTAssertLessThan(recorder.distanceMeters, 1)
    }

    func testImplausibleJumpIsRejected() {
        let recorder = recorder()
        recorder.prepare()
        recorder.start()

        let start = Date()
        recorder.ingest([
            RoutePoint(
                latitude: 1.3000,
                longitude: 103.8700,
                altitude: 0,
                timestamp: start,
                horizontalAccuracy: 5,
                speed: 3
            )
        ])
        // Half a degree away in one second is not running.
        recorder.ingest([
            RoutePoint(
                latitude: 1.8000,
                longitude: 103.8700,
                altitude: 0,
                timestamp: start.addingTimeInterval(1),
                horizontalAccuracy: 5,
                speed: 3
            )
        ])

        XCTAssertEqual(recorder.distanceMeters, 0, accuracy: 0.01)
        XCTAssertEqual(recorder.points.count, 1)
    }

    func testPauseStopsTheClock() {
        let recorder = recorder()
        recorder.prepare()
        recorder.start()

        let start = Date()
        recorder.tick(now: start)
        recorder.tick(now: start.addingTimeInterval(10))
        XCTAssertEqual(recorder.elapsedTime, 10, accuracy: 0.5)

        recorder.pause()
        recorder.tick(now: start.addingTimeInterval(60))
        // Time after a pause is not counted.
        XCTAssertEqual(recorder.elapsedTime, 10, accuracy: 0.5)
    }

    func testAutoPauseWaitsForARealStop() {
        let recorder = recorder()
        recorder.prepare()
        recorder.start()

        let start = Date()
        // Cover some ground first.
        for index in 0..<5 {
            recorder.ingest([
                RoutePoint(
                    latitude: 1.3000 + Double(index) * 0.0002,
                    longitude: 103.8700,
                    altitude: 0,
                    timestamp: start.addingTimeInterval(Double(index) * 2),
                    horizontalAccuracy: 5,
                    speed: 3
                )
            ])
        }
        XCTAssertEqual(recorder.phase, .recording)

        // Ten seconds of standing still is not enough.
        recorder.tick(now: start.addingTimeInterval(24))
        XCTAssertEqual(recorder.phase, .recording)

        // Twenty seconds is.
        recorder.tick(now: start.addingTimeInterval(34))
        XCTAssertEqual(recorder.phase, .paused)
        XCTAssertTrue(recorder.isAutoPaused)
    }

    func testRunKeepsTheRouteThatWasRun() {
        let recorder = recorder()
        recorder.prepare()
        recorder.start()

        let start = Date()
        for index in 0..<8 {
            recorder.ingest([
                RoutePoint(
                    latitude: 1.3000 + Double(index) * 0.0001,
                    longitude: 103.8700,
                    altitude: 0,
                    timestamp: start.addingTimeInterval(Double(index) * 2),
                    horizontalAccuracy: 5,
                    speed: 3
                )
            ])
        }

        let run = recorder.makeRun(title: "Test run", note: "A note")
        XCTAssertEqual(run.points.count, 8)
        XCTAssertEqual(run.title, "Test run")
        XCTAssertEqual(run.note, "A note")
        XCTAssertGreaterThan(run.distanceMeters, 50)
        XCTAssertEqual(run.source, .recorded)
    }
}
