import Foundation
import Observation

/// The settings the reader has chosen.
///
/// There are very few of them, and they are kept in the system's own
/// preferences rather than in the runs file: they are not runs, and they
/// should not travel with them.
@MainActor
@Observable
public final class Preferences {
    /// How the map is drawn.
    public var mapStyle: MapStyle {
        didSet { defaults.set(mapStyle.rawValue, forKey: Keys.mapStyle) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let mapStyle = "milemark.mapStyle"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // -mapStyle=standard sets the style for a screenshot or a UI check.
        // Without it the reader's own choice is used.
        let requested = ProcessInfo.processInfo.arguments
            .first(where: { $0.hasPrefix("-mapStyle=") })?
            .replacingOccurrences(of: "-mapStyle=", with: "")
        if let requested, let style = MapStyle(rawValue: requested) {
            self.mapStyle = style
            return
        }
        let stored = defaults.string(forKey: Keys.mapStyle) ?? ""
        self.mapStyle = MapStyle(rawValue: stored) ?? .milemark
    }
}
