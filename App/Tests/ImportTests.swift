import CoreLocation
import XCTest
@testable import Milemark

/// The encoded polyline that Strava sends has to come back as a route.
final class PolylineTests: XCTestCase {
    /// A two-point route from Google's own documentation.
    ///
    /// `(38.5, -120.2)` then `(40.7, -120.95)`.
    func testDecodesAKnownRoute() {
        let coordinates = Polyline.decode("_p~iF~ps|U_ulLnnqC_mqNvxq`@")
        XCTAssertEqual(coordinates.count, 3)
        XCTAssertEqual(coordinates[0].latitude, 38.5, accuracy: 0.00001)
        XCTAssertEqual(coordinates[0].longitude, -120.2, accuracy: 0.00001)
        XCTAssertEqual(coordinates[1].latitude, 40.7, accuracy: 0.00001)
        XCTAssertEqual(coordinates[1].longitude, -120.95, accuracy: 0.00001)
    }

    func testAnEmptyPolylineIsNoRoute() {
        XCTAssertTrue(Polyline.decode("").isEmpty)
    }

    /// A malformed polyline gives no route at all.
    ///
    /// Half a route is worse than none: it would draw a shape that looks as
    /// though the runner had been somewhere they were not.
    func testAMalformedPolylineIsNoRoute() {
        XCTAssertTrue(Polyline.decode("_p~iF~ps|U_ulL").isEmpty)
        XCTAssertTrue(Polyline.decode("not a polyline").isEmpty)
    }

    /// A separator starts a new stretch of the route.
    func testSeparatorsAreSkipped() {
        let coordinates = Polyline.decode("_p~iF~ps|U_ulLnnqC|_mqNvxq`@")
        XCTAssertEqual(coordinates.count, 3)
    }
}

/// A Strava activity becomes a run the archive can hold.
final class StravaMappingTests: XCTestCase {
    private func makeActivity(
        id: Int = 99,
        name: String = "Morning Run",
        distance: Double = 5000,
        movingTime: Int = 1500,
        polyline: String? = "_p~iF~ps|U_ulLnnqC_mqNvxq`@"
    ) -> StravaActivity {
        let json = """
        {
          "id": \(id),
          "name": "\(name)",
          "distance": \(distance),
          "moving_time": \(movingTime),
          "elapsed_time": \(movingTime + 60),
          "total_elevation_gain": 24.5,
          "type": "Run",
          "sport_type": "Run",
          "start_date": "2026-03-04T23:30:00Z",
          "average_heartrate": 152.4,
          "map": \(polyline.map { "\(String(repeating: "null", count: 0))" + "{\"polyline\": \"\($0)\"}" } ?? "null")
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try! decoder.decode(StravaActivity.self, from: Data(json.utf8))
    }

    func testAnActivityBecomesARun() {
        let run = StravaRunMapper.makeRun(from: makeActivity())

        XCTAssertEqual(run.title, "Morning Run")
        XCTAssertEqual(run.distanceMeters, 5000)
        XCTAssertEqual(run.movingTime, 1500)
        XCTAssertEqual(run.elapsedTime, 1560)
        XCTAssertEqual(run.elevationGainMeters, 24.5)
        XCTAssertEqual(run.averageHeartRate, 152)
        XCTAssertEqual(run.source, .imported)
        XCTAssertEqual(run.sourceID, "99")
        XCTAssertEqual(run.sourceName, "Strava")
    }

    /// The route comes back as points, with the time spread across them.
    func testTheRouteBecomesPoints() {
        let run = StravaRunMapper.makeRun(from: makeActivity())
        XCTAssertEqual(run.points.count, 3)
        XCTAssertEqual(run.points.first?.timestamp, run.startedAt)
        // The last point is the end of the moving time.
        let span = run.points.last?.timestamp.timeIntervalSince(run.startedAt) ?? -1
        XCTAssertEqual(span, run.movingTime, accuracy: 0.001)
    }

    /// An activity with no route still becomes a run.
    func testAnActivityWithoutARouteStillBecomesARun() {
        let run = StravaRunMapper.makeRun(from: makeActivity(polyline: nil))
        XCTAssertTrue(run.points.isEmpty)
        XCTAssertEqual(run.distanceMeters, 5000)
    }

    /// An empty name is replaced with something that says what the thing was.
    func testAnEmptyNameIsReplaced() {
        let run = StravaRunMapper.makeRun(from: makeActivity(name: "   "))
        XCTAssertEqual(run.title, "Run")
    }
}

/// A token that has run out is refreshed; one that has not, is not.
final class OAuthTokenTests: XCTestCase {
    func testAFreshTokenIsNotExpired() {
        let token = OAuthToken(
            accessToken: "a",
            refreshToken: "b",
            expiresAt: Date().addingTimeInterval(3600)
        )
        XCTAssertFalse(token.isExpired())
    }

    func testAnExpiredTokenIsExpired() {
        let token = OAuthToken(
            accessToken: "a",
            refreshToken: "b",
            expiresAt: Date().addingTimeInterval(-10)
        )
        XCTAssertTrue(token.isExpired())
    }

    /// A token that is about to run out is treated as expired, so a request
    /// is not sent with a token that dies while it is in flight.
    func testATokenAboutToExpireIsTreatedAsExpired() {
        let token = OAuthToken(
            accessToken: "a",
            refreshToken: "b",
            expiresAt: Date().addingTimeInterval(30)
        )
        XCTAssertTrue(token.isExpired())
    }
}

/// An error the reader can act on.
final class ImportErrorTests: XCTestCase {
    /// A Swift error that does not say anything falls back to a generic
    /// message with the type's name and a number in it. The reader is shown
    /// the message instead.
    func testTheStravaErrorsSayWhatTheyMean() {
        XCTAssertEqual(StravaError.cancelled.errorDescription, "The authorisation was cancelled.")
        XCTAssertEqual(StravaError.notConnected.errorDescription, "Connect to Strava first.")
        XCTAssertEqual(
            StravaError.server(status: 401, message: "Bad Request").errorDescription,
            "Bad Request"
        )
        XCTAssertNotNil(StravaError.notConfigured.errorDescription)
    }

    func testTheHealthErrorsSayWhatTheyMean() {
        XCTAssertEqual(
            HealthError.authorizationNotDetermined.errorDescription,
            "Milemark has not been allowed to read Health yet."
        )
        XCTAssertEqual(
            HealthError.entitlementMissing.errorDescription,
            "This build of Milemark cannot read Health."
        )
    }

    /// The description is what the reader sees, so it must never be the
    /// generic fallback.
    func testNoErrorShowsTheGenericFallback() {
        let errors: [LocalizedError] = [
            StravaError.cancelled,
            StravaError.notConnected,
            StravaError.notConfigured,
            StravaError.badResponse,
            StravaError.couldNotStoreToken,
            StravaError.server(status: 500, message: nil),
            HealthError.unavailable,
            HealthError.authorizationNotDetermined,
            HealthError.authorizationDenied,
            HealthError.entitlementMissing,
        ]
        for error in errors {
            let description = error.errorDescription ?? ""
            XCTAssertFalse(description.isEmpty, "\(error) has no description.")
            // The generic fallback is the system's own wording, with the
            // type's name and a number in it.
            XCTAssertFalse(
                description.contains("couldn\u{2019}t be completed"),
                "\(error) would show the generic fallback: \(description)"
            )
            XCTAssertFalse(
                description.contains("Milemark."),
                "\(error) would show the generic fallback: \(description)"
            )
        }
    }
}
