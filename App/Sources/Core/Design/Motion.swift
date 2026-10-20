import SwiftUI

/// The app's motion settings.
///
/// Motion is reduced for two reasons: the reader has asked the system for less
/// movement, or the app is running somewhere that cannot animate well. When
/// motion is reduced, nothing disappears: the paper is still there, the map is
/// still printed, and every action still works. Only the travel is removed.
public enum Motion {
    /// Whether travelling movement should be used.
    public static func allowsTravel(_ reduceMotion: Bool) -> Bool {
        !reduceMotion
    }

    /// The duration of a short, interruptible change.
    public static func short(_ reduceMotion: Bool) -> TimeInterval {
        reduceMotion ? 0.12 : 0.26
    }

    /// The duration of the paper feeding out of the tray.
    public static func feed(_ reduceMotion: Bool) -> TimeInterval {
        reduceMotion ? 0.14 : 1.1
    }

    /// The duration of a map or a photograph being printed.
    public static func print(_ reduceMotion: Bool) -> TimeInterval {
        reduceMotion ? 0.1 : 0.5
    }

    /// The duration of the receipt being pulled away.
    public static func tear(_ reduceMotion: Bool) -> TimeInterval {
        reduceMotion ? 0.14 : 0.42
    }
}
