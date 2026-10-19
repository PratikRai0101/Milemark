import CoreLocation
import Foundation

/// A single recorded location sample.
///
/// Samples keep their own timestamp and accuracy so the recorder can reject bad
/// fixes after the fact instead of trusting them blindly. Latitude and
/// longitude are stored as plain doubles rather than a CoreLocation struct so
/// the whole model stays `Sendable`.
public struct RoutePoint: Codable, Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public var altitude: Double
    public var timestamp: Date
    public var horizontalAccuracy: Double
    public var speed: Double

    public init(
        latitude: Double,
        longitude: Double,
        altitude: Double,
        timestamp: Date,
        horizontalAccuracy: Double,
        speed: Double
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.timestamp = timestamp
        self.horizontalAccuracy = horizontalAccuracy
        self.speed = speed
    }

    public init(location: CLLocation) {
        self.init(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            timestamp: location.timestamp,
            horizontalAccuracy: location.horizontalAccuracy,
            speed: max(0, location.speed)
        )
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// A finished or in-progress run.
public struct Run: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var note: String
    public var startedAt: Date
    public var endedAt: Date
    /// Wall-clock duration, including paused time.
    public var elapsedTime: TimeInterval
    /// Time spent actually moving.
    public var movingTime: TimeInterval
    public var distanceMeters: Double
    public var elevationGainMeters: Double
    public var averageHeartRate: Int?
    public var points: [RoutePoint]
    /// Indices in `points` where the track resumes after a pause. No distance
    /// is counted across these gaps and no line is drawn between them.
    public var segmentBreaks: [Int]
    /// Whether the user has kept this receipt in their collection.
    public var isCollected: Bool
    public var source: Source

    public enum Source: String, Codable, Sendable {
        case recorded
        case imported
    }

    public init(
        id: UUID = UUID(),
        title: String,
        note: String = "",
        startedAt: Date,
        endedAt: Date,
        elapsedTime: TimeInterval,
        movingTime: TimeInterval,
        distanceMeters: Double,
        elevationGainMeters: Double,
        averageHeartRate: Int? = nil,
        points: [RoutePoint],
        segmentBreaks: [Int] = [],
        isCollected: Bool = false,
        source: Source = .recorded
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.elapsedTime = elapsedTime
        self.movingTime = movingTime
        self.distanceMeters = distanceMeters
        self.elevationGainMeters = elevationGainMeters
        self.averageHeartRate = averageHeartRate
        self.points = points
        self.segmentBreaks = segmentBreaks
        self.isCollected = isCollected
        self.source = source
    }
}
