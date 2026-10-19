import XCTest
@testable import Milemark

final class RouteGeometryTests: XCTestCase {
    private func point(
        _ latitude: Double,
        _ longitude: Double,
        at offset: TimeInterval = 0
    ) -> RoutePoint {
        RoutePoint(
            latitude: latitude,
            longitude: longitude,
            altitude: 0,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000 + offset),
            horizontalAccuracy: 5,
            speed: 3
        )
    }

    /// A sample from right now, which is what an acceptable fix looks like.
    private func freshPoint(_ latitude: Double = 1.3, _ longitude: Double = 103.8) -> RoutePoint {
        RoutePoint(
            latitude: latitude,
            longitude: longitude,
            altitude: 0,
            timestamp: Date(),
            horizontalAccuracy: 5,
            speed: 3
        )
    }

    func testDistanceBetweenCoordinatesIsAccurate() {
        // Roughly 111 m per 0.001 degree of latitude.
        let metres = RouteGeometry.distance(from: 1.3, longitude1: 103.8, to: 1.301, longitude2: 103.8)
        XCTAssertEqual(metres, 111.2, accuracy: 2)
    }

    func testTotalDistanceSumsSegments() {
        let points = [point(1.3, 103.8), point(1.301, 103.8), point(1.302, 103.8)]
        XCTAssertEqual(RouteGeometry.totalDistance(points), 222.4, accuracy: 3)
    }

    func testBreakDoesNotAddDistance() {
        let points = [point(1.3, 103.8), point(1.301, 103.8), point(1.302, 103.8)]
        let withBreak = RouteGeometry.totalDistance(points, breaks: [2])
        XCTAssertEqual(withBreak, 111.2, accuracy: 3)
    }

    func testPaceIsNilWithoutDistance() {
        XCTAssertNil(RouteGeometry.paceSecondsPerKm(distanceMeters: 0, movingTime: 100))
        XCTAssertNil(RouteGeometry.paceSecondsPerKm(distanceMeters: 1000, movingTime: 0))
    }

    func testPaceSecondsPerKilometre() {
        // 5 minutes 30 seconds per kilometre.
        let pace = RouteGeometry.paceSecondsPerKm(distanceMeters: 1000, movingTime: 330)
        XCTAssertEqual(pace ?? 0, 330, accuracy: 0.001)
        XCTAssertEqual(Format.pace(pace), "05′30″")
    }

    func testInaccurateAndStaleFixesAreRejected() {
        var stale = freshPoint()
        stale.timestamp = Date(timeIntervalSinceNow: -60)
        XCTAssertFalse(RouteGeometry.isAcceptable(stale))

        var inaccurate = freshPoint()
        inaccurate.horizontalAccuracy = 120
        XCTAssertFalse(RouteGeometry.isAcceptable(inaccurate))

        var invalid = freshPoint()
        invalid.horizontalAccuracy = -1
        XCTAssertFalse(RouteGeometry.isAcceptable(invalid))

        XCTAssertTrue(RouteGeometry.isAcceptable(freshPoint()))
    }

    func testNormalisationPreservesAspectRatio() {
        // A north-south route is taller than it is wide.
        let points = [point(1.30, 103.80), point(1.31, 103.80)]
        let normalised = RouteGeometry.normalisedPoints(points)
        let width = normalised.map(\.x).max() ?? 0
        let height = normalised.map(\.y).max() ?? 0
        XCTAssertEqual(width, 0, accuracy: 0.001)
        XCTAssertEqual(height, 1, accuracy: 0.001)
    }

    func testNormalisationKeepsTrueShapeOfAWideRoute() {
        // 300 m east, 300 m north. A degree of longitude is slightly shorter
        // than a degree of latitude, so the printed shape must stay close to
        // square rather than being stretched.
        let metresPerDegreeLatitude = 110_574.0
        let metresPerDegreeLongitude = 111_320.0 * cos(1.30 * .pi / 180)
        let points = [
            point(1.30, 103.80),
            point(1.30, 103.80 + 300 / metresPerDegreeLongitude),
            point(1.30 + 300 / metresPerDegreeLatitude, 103.80 + 300 / metresPerDegreeLongitude)
        ]
        let normalised = RouteGeometry.normalisedPoints(points)
        let width = normalised.map(\.x).max() ?? 0
        let height = normalised.map(\.y).max() ?? 0
        XCTAssertEqual(width, 1, accuracy: 0.001)
        XCTAssertEqual(height, 1, accuracy: 0.01)
    }

    func testTrimRemovesEndsOfRoute() {
        let points = (0..<11).map { index in
            point(1.3 + Double(index) * 0.001, 103.8)
        }
        let trimmed = RouteGeometry.trimmed(points, fraction: 0.15)
        XCTAssertLessThan(trimmed.count, points.count)
        XCTAssertGreaterThan(trimmed.count, 1)
        // The first retained point must be further along the route.
        XCTAssertGreaterThan(trimmed.first?.latitude ?? 0, points[0].latitude)
        XCTAssertLessThan(trimmed.last?.latitude ?? 0, points[points.count - 1].latitude)
    }

    func testTrimKeepsShortRoutesIntact() {
        let points = [point(1.3, 103.8), point(1.3001, 103.8)]
        XCTAssertEqual(RouteGeometry.trimmed(points, fraction: 0.15).count, 2)
    }

    func testSplitsCountCompletedKilometres() {
        let points = (0..<21).map { index in
            point(1.3 + Double(index) * 0.001, 103.8, at: TimeInterval(index) * 60)
        }
        let splits = RouteGeometry.splits(points)
        XCTAssertEqual(splits.count, 2)
        XCTAssertEqual(splits.first?.kilometre, 1)
    }

    func testDurationFormatting() {
        XCTAssertEqual(Format.duration(12_265), "03:24:25")
        XCTAssertEqual(Format.duration(278), "04:38")
    }

    func testTheSameRouteIsSimilarToItself() {
        let points = (0..<40).map { index in
            point(1.3000 + Double(index) * 0.0002, 103.8000 + Double(index % 7) * 0.0001)
        }
        XCTAssertEqual(RouteGeometry.similarity(points, points), 1, accuracy: 0.001)
    }

    func testADifferentRouteIsNotSimilar() {
        let first = (0..<40).map { index in
            point(1.3000 + Double(index) * 0.0002, 103.8000)
        }
        let second = (0..<40).map { index in
            point(1.3000, 103.8000 + Double(index) * 0.0002)
        }
        XCTAssertLessThan(RouteGeometry.similarity(first, second), 0.7)
    }

    func testResamplingGivesTheSameNumberOfPoints() {
        let sparse = (0..<5).map { index in point(1.30 + Double(index) * 0.001, 103.80) }
        let dense = (0..<200).map { index in point(1.30 + Double(index) * 0.000025, 103.80) }
        XCTAssertEqual(RouteGeometry.resampled(sparse, count: 32).count, 32)
        XCTAssertEqual(RouteGeometry.resampled(dense, count: 32).count, 32)
        // The same road sampled at different rates still matches.
        XCTAssertGreaterThan(RouteGeometry.similarity(sparse, dense), 0.95)
    }

    func testTheSameLoopWithADifferentNumberOfLapsStillMatches() {
        // One lap of a square.
        let lap: [RoutePoint] = [
            point(1.3000, 103.8000),
            point(1.3000, 103.8010),
            point(1.3010, 103.8010),
            point(1.3010, 103.8000),
            point(1.3000, 103.8000)
        ]
        // Eight laps, then nine: the same route, sampled out of step.
        let eight = Array(repeating: lap, count: 8).flatMap { $0 }
        let nine = Array(repeating: lap, count: 9).flatMap { $0 }
        XCTAssertGreaterThan(RouteGeometry.similarity(eight, nine), 0.95)
    }
}
