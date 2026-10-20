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
        var moment = Date()
        recorder.clock = { moment }
        recorder.prepare()
        recorder.start()

        moment = moment.addingTimeInterval(10)
        recorder.tick()
        XCTAssertEqual(recorder.elapsedTime(), 10, accuracy: 0.5)

        recorder.pause()
        moment = moment.addingTimeInterval(60)
        recorder.tick()
        // Time after a pause is not counted.
        XCTAssertEqual(recorder.elapsedTime(), 10, accuracy: 0.5)
    }

    func testTheClockKeepsCountingWhileTheAppIsSuspended() {
        let recorder = recorder()
        var moment = Date()
        recorder.clock = { moment }
        recorder.prepare()
        recorder.start()

        // The phone is locked for a minute and the timer does not fire.
        moment = moment.addingTimeInterval(60)
        recorder.tick()
        XCTAssertEqual(recorder.elapsedTime(), 60, accuracy: 0.5)
    }

    func testTheClockIsReadEvenWithoutATick() {
        let recorder = recorder()
        var moment = Date()
        recorder.clock = { moment }
        recorder.prepare()
        recorder.start()

        // A minute passes with no tick at all: the app was suspended.
        moment = moment.addingTimeInterval(60)
        XCTAssertEqual(recorder.elapsedTime(), 60, accuracy: 0.5)
    }

    func testAnAutomaticPauseStopsTheClock() {
        let recorder = recorder()
        let start = Date()
        var moment = start
        recorder.clock = { moment }
        recorder.prepare()
        recorder.start()

        // Cover some ground, then stand still.
        for index in 0..<5 {
            recorder.ingest([
                RoutePoint(
                    latitude: 1.3000 + Double(index) * 0.0002,
                    longitude: 103.8000,
                    altitude: 0,
                    timestamp: start.addingTimeInterval(Double(index) * 2),
                    horizontalAccuracy: 5,
                    speed: 3
                )
            ])
        }
        recorder.ingest([
            RoutePoint(
                latitude: 1.3008,
                longitude: 103.8000,
                altitude: 0,
                timestamp: start.addingTimeInterval(10),
                horizontalAccuracy: 5,
                speed: 0
            )
        ])

        moment = start.addingTimeInterval(32)
        recorder.tick()
        XCTAssertEqual(recorder.phase, .paused)
        XCTAssertTrue(recorder.isAutoPaused)

        // The clock stopped with the pause.
        let atPause = recorder.elapsedTime()
        moment = start.addingTimeInterval(180)
        XCTAssertEqual(recorder.elapsedTime(), atPause, accuracy: 0.5)

        // Resuming starts the clock again.
        recorder.resume()
        moment = start.addingTimeInterval(190)
        XCTAssertEqual(recorder.elapsedTime(), atPause + 10, accuracy: 0.5)
    }

    func testAutoPauseWaitsForARealStop() {
        let recorder = recorder()
        var moment = Date()
        recorder.clock = { moment }
        recorder.prepare()
        recorder.start()

        let start = moment
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

        // The runner stops: a still sample, and then no more movement.
        recorder.ingest([
            RoutePoint(
                latitude: 1.3008,
                longitude: 103.8700,
                altitude: 0,
                timestamp: start.addingTimeInterval(10),
                horizontalAccuracy: 5,
                speed: 0
            )
        ])

        // Ten seconds of standing still is not enough.
        moment = start.addingTimeInterval(20)
        recorder.tick()
        XCTAssertEqual(recorder.phase, .recording)

        // Twenty seconds is.
        moment = start.addingTimeInterval(32)
        recorder.tick()
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
