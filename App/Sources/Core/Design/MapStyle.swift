import Foundation
import MapKit

/// How the map is drawn.
///
/// MapKit draws the basemap; the app decides how loud it is, what is left
/// off it, and what is inked on top of it. Those decisions are the style.
///
/// Apple does not let an app repaint the map itself — that would need a
/// vector tile source and a server, which this app does not have and does not
/// want. What it does let an app do is hold Apple's map back, take pieces
/// off it, and draw over it. That is enough to make the map belong to the
/// app rather than to the system.
public enum MapStyle: String, CaseIterable, Identifiable, Sendable {
    /// The app's own style: Apple's basemap held back to a whisper, with
    /// nothing on it but the route.
    case milemark
    /// Apple's map as it normally comes, with its labels, its pins and its
    /// traffic.
    case standard

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .milemark: "Milemark"
        case .standard: "Standard"
        }
    }

    /// What the style does, in a sentence.
    public var explanation: String {
        switch self {
        case .milemark:
            "A quiet basemap with nothing on it but the route."
        case .standard:
            "Apple's map as it normally comes."
        }
    }

    /// The MapKit configuration this style is built from.
    public func configuration() -> MKMapConfiguration {
        switch self {
        case .milemark:
            // Flat, because a run is on the ground. Muted, because the route
            // is the content and the map is the ground. No points of
            // interest, because a restaurant pin is not a run. No traffic,
            // because nobody runs into a jam on purpose.
            let configuration = MKStandardMapConfiguration(
                elevationStyle: .flat,
                emphasisStyle: .muted
            )
            configuration.showsTraffic = false
            configuration.pointOfInterestFilter = .excludingAll
            return configuration

        case .standard:
            let configuration = MKStandardMapConfiguration(
                elevationStyle: .realistic,
                emphasisStyle: .default
            )
            configuration.showsTraffic = true
            configuration.pointOfInterestFilter = .includingAll
            return configuration
        }
    }

    /// Whether the route is inked in the app's own colours and the markers
    /// are drawn by the app.
    public var drawsItsOwnRoute: Bool {
        self == .milemark
    }
}
