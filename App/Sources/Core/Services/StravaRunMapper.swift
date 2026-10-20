import CoreLocation
import Foundation

/// Turns an activity from another service into a run the archive can hold.
///
/// The mapping is deliberately faithful about what it knows and careful about
/// what it does not. A route's distance and time come straight from the
/// source. The time at each point does not: Strava sends a shape, not a
/// recording, so the points are spread evenly across the moving time. That
/// gives a receipt with the right distance and the right pace, and it does
/// not pretend to know where the runner was at any particular second.
public enum StravaRunMapper {
    /// Builds a run from a Strava activity.
    public static func makeRun(from activity: StravaActivity) -> Run {
        let coordinates = activity.routeCoordinates
        let startedAt = activity.startDate
        let movingTime = TimeInterval(activity.movingTime)
        let points = makePoints(coordinates: coordinates, startedAt: startedAt, movingTime: movingTime)

        return Run(
            title: activity.displayName,
            note: "",
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(TimeInterval(activity.elapsedTime)),
            elapsedTime: TimeInterval(activity.elapsedTime),
            movingTime: movingTime,
            distanceMeters: activity.distance,
            elevationGainMeters: activity.totalElevationGain,
            averageHeartRate: activity.averageHeartRate.map { Int($0.rounded()) },
            points: points,
            source: .imported,
            sourceID: String(activity.id),
            sourceName: "Strava"
        )
    }

    /// Spreads the points across the moving time.
    private static func makePoints(
        coordinates: [CLLocationCoordinate2D],
        startedAt: Date,
        movingTime: TimeInterval
    ) -> [RoutePoint] {
        guard !coordinates.isEmpty else { return [] }

        // The last point is the end of the run, so the interval between
        // points is the moving time divided by the number of gaps.
        let gaps = max(coordinates.count - 1, 1)
        let interval = movingTime / Double(gaps)

        return coordinates.enumerated().map { index, coordinate in
            RoutePoint(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                altitude: 0,
                timestamp: startedAt.addingTimeInterval(interval * Double(index)),
                horizontalAccuracy: 0,
                speed: 0
            )
        }
    }
}
