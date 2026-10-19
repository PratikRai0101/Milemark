import CoreGraphics

/// The rule for pulling a receipt off its slot.
///
/// The pull is measured in points, not as a fraction, so the paper moves with
/// the finger. Past the threshold the receipt is collected; short of it, the
/// paper springs back into the slot.
public enum TearRule {
    /// How far the paper has to be pulled before it comes away.
    public static let threshold: CGFloat = 72
    /// The pull that moves the paper all the way down.
    public static let fullTravel: CGFloat = 90

    /// Whether a pull of this distance tears the receipt off.
    public static func shouldTear(translation: CGFloat) -> Bool {
        translation > threshold
    }

    /// How far the paper has travelled, from 0 to 1.
    public static func progress(for translation: CGFloat) -> CGFloat {
        min(1, max(0, translation / fullTravel))
    }
}
