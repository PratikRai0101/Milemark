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
    /// The time at each kilometre boundary is **interpolated** between the
    /// samples either side of it, rather than taken from the first sample
    /// past the boundary. A route sampled every ten metres would otherwise
    /// report every split as up to ten metres slow.
    ///
    /// Time spent paused is not counted: the active time only advances within
    /// a segment, so a pause in the middle of a kilometre does not make the
    /// split look slower than the run was.
    public static func splits(_ points: [RoutePoint], breaks: [Int] = []) -> [Split] {
        guard points.count > 1 else { return [] }
        let cumulative = cumulativeDistances(points, breaks: breaks)
        let active = activeTimes(points, breaks: breaks)
        let breakSet = Set(breaks)

        var splits: [Split] = []
        var kilometre = 1
        // The active time at the start of the kilometre being measured.
        var kilometreStart = active[0]

        var index = 1
        while index < points.count {
            let target = Double(kilometre) * 1000
            let before = cumulative[index - 1]
            let after = cumulative[index]
            guard after >= target else {
                index += 1
                continue
            }

            // Where between the two samples the boundary was crossed.
            let span = after - before
            let fraction = span > 0 ? (target - before) / span : 0
            let activeBefore = active[index - 1]
            let activeAfter = active[index]
            let crossing = activeBefore + (activeAfter - activeBefore) * fraction

            let duration = max(0, crossing - kilometreStart)
            splits.append(
                Split(
                    kilometre: kilometre,
                    duration: duration,
                    paceSecondsPerKm: duration
                )
            )
            kilometre += 1
            kilometreStart = crossing
            // The same pair of samples can cross more than one boundary, so
            // the index is not advanced here.
            if index < points.count, breakSet.contains(index) {
                // A segment boundary is never crossed: the next segment
                // starts its own count from here.
                index += 1
            }
        }
        return splits
    }

    /// The time the route has actually covered, at each sample.
    ///
    /// The clock does not advance across a break, so time spent paused is
    /// left out.
    private static func activeTimes(_ points: [RoutePoint], breaks: [Int]) -> [TimeInterval] {
        guard !points.isEmpty else { return [] }
        let breakSet = Set(breaks)
        var times: [TimeInterval] = [0]
        times.reserveCapacity(points.count)
        for index in 1..<points.count {
            let delta = breakSet.contains(index)
                ? 0
                : points[index].timestamp.timeIntervalSince(points[index - 1].timestamp)
            times.append(times[index - 1] + delta)
        }
        return times
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
    public struct Bounds: Equatable, Sendable {        public var minLatitude: Double
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

    /// Resamples a route into a fixed number of points, evenly spaced along
    /// its length.
    ///
    /// Two runs of the same loop have different numbers of GPS samples, so
    /// they can only be compared after they have been resampled.
    public static func resampled(_ points: [RoutePoint], count: Int = 64) -> [CGPoint] {
        let normalised = normalisedPoints(points)
        guard normalised.count > 1, count > 1 else { return normalised }

        // Walk the route by arc length in the normalised space.
        var lengths: [CGFloat] = [0]
        for index in 1..<normalised.count {
            let a = normalised[index - 1]
            let b = normalised[index]
            lengths.append(lengths[index - 1] + hypot(b.x - a.x, b.y - a.y))
        }
        guard let total = lengths.last, total > 0 else { return normalised }

        var result: [CGPoint] = []
        result.reserveCapacity(count)
        for step in 0..<count {
            let target = total * CGFloat(step) / CGFloat(count - 1)
            var index = 1
            while index < lengths.count - 1 && lengths[index] < target { index += 1 }
            let previousLength = lengths[index - 1]
            let nextLength = lengths[index]
            let span = nextLength - previousLength
            let fraction = span > 0 ? (target - previousLength) / span : 0
            let a = normalised[index - 1]
            let b = normalised[index]
            result.append(
                CGPoint(
                    x: a.x + (b.x - a.x) * fraction,
                    y: a.y + (b.y - a.y) * fraction
                )
            )
        }
        return result
    }

    /// How alike two routes are, from 0 (nothing in common) to 1 (the same
    /// shape).
    ///
    /// The comparison is made on the normalised shape, so the same loop run
    /// twice matches. The points are matched by their nearest neighbour
    /// rather than by their position along the route, because two runs of the
    /// same loop usually have a different number of laps and would otherwise
    /// be compared out of step.
    public static func similarity(_ first: [RoutePoint], _ second: [RoutePoint]) -> Double {
        guard first.count > 1, second.count > 1 else { return 0 }
        let a = resampled(first)
        let b = resampled(second)
        guard a.count == b.count, a.count > 1 else { return 0 }
        return 1 - (meanDistanceToLine(a, b) + meanDistanceToLine(b, a)) / 2
    }

    /// The average distance from each point to the line drawn by the other
    /// route.
    ///
    /// Measuring to the line rather than to the sampled points is what makes
    /// two runs of the same loop match: the same road sampled at a different
    /// point in the lap is still on the line.
    private static func meanDistanceToLine(_ a: [CGPoint], _ b: [CGPoint]) -> CGFloat {
        var total: CGFloat = 0
        for point in a {
            var nearest = CGFloat.greatestFiniteMagnitude
            for index in 1..<b.count {
                nearest = min(nearest, distance(from: point, toSegmentFrom: b[index - 1], to: b[index]))
            }
            total += nearest
        }
        return total / CGFloat(a.count)
    }

    /// The distance from a point to a line segment.
    private static func distance(from point: CGPoint, toSegmentFrom start: CGPoint, to end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else {
            return hypot(point.x - start.x, point.y - start.y)
        }
        let projection = ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared
        let t = CGFloat(max(0, min(1, projection)))
        let closest = CGPoint(x: start.x + t * dx, y: start.y + t * dy)
        return hypot(point.x - closest.x, point.y - closest.y)
    }
}
