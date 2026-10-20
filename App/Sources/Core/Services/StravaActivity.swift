import CoreLocation
import Foundation

/// One activity from Strava's activity list.
///
/// Only the fields the receipt actually uses are modelled. Strava sends a
/// great deal more than that, and modelling all of it would be modelling
/// nothing in particular.
public struct StravaActivity: Decodable, Sendable, Identifiable {
    public var id: Int
    public var name: String
    public var distance: Double
    public var movingTime: Int
    public var elapsedTime: Int
    public var totalElevationGain: Double
    public var type: String
    public var sportType: String?
    public var startDate: Date
    public var averageHeartRate: Double?
    public var maxHeartRate: Double?
    public var map: Map?

    public struct Map: Decodable, Sendable {
        public var polyline: String?
        public var summaryPolyline: String?
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case distance
        case movingTime = "moving_time"
        case elapsedTime = "elapsed_time"
        case totalElevationGain = "total_elevation_gain"
        case type
        case sportType = "sport_type"
        case startDate = "start_date"
        case averageHeartRate = "average_heartrate"
        case maxHeartRate = "max_heartrate"
        case map
    }

    /// The route as a list of points, if Strava sent one.
    ///
    /// The full polyline is preferred; the summary is the same route with
    /// the detail thinned out, and is used only when the full one is absent.
    public var routeCoordinates: [CLLocationCoordinate2D] {
        let encoded = map?.polyline ?? map?.summaryPolyline
        guard let encoded, !encoded.isEmpty else { return [] }
        return Polyline.decode(encoded)
    }

    /// The name to print on the receipt.
    ///
    /// Strava's names are often a place, a time or a single word. An empty
    /// name is replaced with something that says what the thing was.
    public var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return sportType ?? type }
        return trimmed
    }
}
