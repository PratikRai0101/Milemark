import CoreLocation
import Foundation

/// Pure geometry and metric helpers.
///
/// Everything here is deterministic and free of UIKit so it can be unit tested
/// directly. The rules below are what stop a run from being a plausible-looking
/// lie: stale fixes, wild jumps and standing-still noise are rejected instead
/// of being smoothed into a nicer line.
///
/// A route can contain **breaks** — indices where the track resumes after a
/// pause. Distance is never accumulated across a break, and no straight line is
/// drawn between the two sides of one.
public enum RouteGeometry {
    /// A location fix is only trusted when it is recent and reasonably precise.
    public static func isAcceptable(_ point: RoutePoint, now: Date = .now) -> Bool {
        guard point.horizontalAccuracy >= 0, point.horizontalAccuracy <= 40 else { return false }
        guard now.timeIntervalSince(point.timestamp) < 10 else { return false }
        return true
    }

    /// Distance between two coordinates, in metres.
    public static func distance(
        from latitude1: Double,
        longitude1: Double,
        to latitude2: Double,
        longitude2: Double
    ) -> Double {
        let earthRadius = 6_378_137.0
        let dLat = (latitude2 - latitude1) * .pi / 180
        let dLon = (longitude2 - longitude1) * .pi / 180
        let lat1 = latitude1 * .pi / 180
        let lat2 = latitude2 * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2)
        return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    /// Splits a route into the continuous pieces between breaks.
    public static func segments(_ points: [RoutePoint], breaks: [Int]) -> [ArraySlice<RoutePoint>] {
        guard !points.isEmpty else { return [] }
        let sortedBreaks = breaks.filter { $0 > 0 && $0 < points.count }.sorted()
        var result: [ArraySlice<RoutePoint>] = []
        var start = 0
        for boundary in sortedBreaks {
            result.append(points[start..<boundary])
            start = boundary
        }
        result.append(points[start...])
        return result
    }

    /// Cumulative distance in metres along a route, ignoring gaps at breaks.
    public static func cumulativeDistances(_ points: [RoutePoint], breaks: [Int] = []) -> [Double] {
        var total = 0.0
        var result: [Double] = []
        result.reserveCapacity(points.count)
        let breakSet = Set(breaks)
        for (index, point) in points.enumerated() {
            if index > 0, !breakSet.contains(index) {
                let previous = points[index - 1]
                total += distance(
                    from: previous.latitude,
                    longitude1: previous.longitude,
                    to: point.latitude,
                    longitude2: point.longitude
                )
            }
            result.append(total)
        }
        return result
    }

    /// Total length of a route in metres.
    public static func totalDistance(_ points: [RoutePoint], breaks: [Int] = []) -> Double {
        cumulativeDistances(points, breaks: breaks).last ?? 0
    }

    /// Seconds per kilometre, or `nil` when there is no meaningful distance.
    public static func paceSecondsPerKm(distanceMeters: Double, movingTime: TimeInterval) -> Double? {
        guard distanceMeters > 1, movingTime > 0 else { return nil }
        return movingTime / (distanceMeters / 1000)
    }

    /// Per-kilometre splits with their cumulative durations.
    public struct Split: Equatable, Sendable {
        public let kilometre: Int
        public let duration: TimeInterval
        public let paceSecondsPerKm: Double
    }

    /// Splits for each completed kilometre of a route.
    ///
    /// A split's duration is the time taken to travel the kilometre that ended
    /// at that boundary, so the pace of each split is that same duration.
    public static func splits(_ points: [RoutePoint], breaks: [Int] = []) -> [Split] {
        guard points.count > 1 else { return [] }
        let cumulative = cumulativeDistances(points, breaks: breaks)
        var splits: [Split] = []
        var kilometre = 1
        var previousTime = points[0].timestamp

        for index in 1..<points.count {
            let target = Double(kilometre) * 1000
            guard cumulative[index] >= target else { continue }
            let duration = points[index].timestamp.timeIntervalSince(previousTime)
            splits.append(
                Split(
                    kilometre: kilometre,
                    duration: duration,
                    paceSecondsPerKm: duration
                )
            )
            previousTime = points[index].timestamp
            kilometre += 1
        }
        return splits
    }

    /// Projects a route into a unit square, preserving aspect ratio so a printed
    /// silhouette always looks like the shape that was actually run.
    ///
    /// The projection works in metres, not degrees: a degree of longitude is
    /// shorter than a degree of latitude away from the equator, and using
    /// degrees directly would squash every route.
    public static func normalisedPoints(_ points: [RoutePoint]) -> [CGPoint] {
        guard points.count > 1 else { return points.map { _ in .zero } }
        let bounds = bounds(of: points)
        let midLatitude = (bounds.minLatitude + bounds.maxLatitude) / 2
        let metresPerDegreeLatitude = 110_574.0
        let metresPerDegreeLongitude = 111_320.0 * cos(midLatitude * .pi / 180)

        var result: [CGPoint] = []
        result.reserveCapacity(points.count)
        for point in points {
            let x = (point.longitude - bounds.minLongitude) * metresPerDegreeLongitude
            let y = (point.latitude - bounds.minLatitude) * metresPerDegreeLatitude
            result.append(CGPoint(x: x, y: y))
        }
        let maxX = result.map(\.x).max() ?? 1
        let maxY = result.map(\.y).max() ?? 1

        // Fit into the unit square on the longer axis, so the shape is only
        // ever scaled down and never distorted.
        let scale = 1 / Swift.max(maxX, maxY)
        result = result.map { CGPoint(x: $0.x * scale, y: $0.y * scale) }
        return result
    }

    /// Removes the first and last portion of a route by fraction of its
    /// length, so a shared preview does not expose where a run started or
    /// ended.
    public static func trimmed(_ points: [RoutePoint], fraction: Double) -> [RoutePoint] {
        guard points.count > 2, fraction > 0, fraction < 0.5 else { return points }
        let cumulative = cumulativeDistances(points)
        guard let total = cumulative.last, total > 0 else { return points }
        let lowerBound = total * fraction
        let upperBound = total * (1 - fraction)
        var result: [RoutePoint] = []
        for (index, point) in points.enumerated() {
            if cumulative[index] >= lowerBound && cumulative[index] <= upperBound {
                result.append(point)
            }
        }
        return result.count >= 2 ? result : points
    }

    /// Bounding box of a set of points, with a minimum span so a single-point
    /// route still produces a usable box.
    public struct Bounds: Equatable, Sendable {
        public var minLatitude: Double
        public var maxLatitude: Double
        public var minLongitude: Double
        public var maxLongitude: Double

        public static let empty = Bounds(
            minLatitude: .greatestFiniteMagnitude,
            maxLatitude: -.greatestFiniteMagnitude,
            minLongitude: .greatestFiniteMagnitude,
            maxLongitude: -.greatestFiniteMagnitude
        )
    }

    public static func bounds(of points: [RoutePoint]) -> Bounds {
        guard !points.isEmpty else { return .empty }
        var bounds = Bounds.empty
        for point in points {
            bounds.minLatitude = min(bounds.minLatitude, point.latitude)
            bounds.maxLatitude = max(bounds.maxLatitude, point.latitude)
            bounds.minLongitude = min(bounds.minLongitude, point.longitude)
            bounds.maxLongitude = max(bounds.maxLongitude, point.longitude)
        }
        return bounds
    }
}
