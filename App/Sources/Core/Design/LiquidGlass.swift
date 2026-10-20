import SwiftUI

/// A bar that sits on Liquid Glass where the system provides it.
///
/// The app supports iOS 18 and later, and the system glass material arrived
/// in iOS 26. Rather than raise the deployment target and leave most phones
/// behind, the bar uses the real material where it exists and falls back to a
/// flat equivalent that is drawn to match.
///
/// The fallback is not a placeholder: it has the same shape, the same spacing
/// and the same press response, so the bar does not feel broken on an older
/// phone.
struct LiquidGlassBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 8) {
                content
                    .glassEffect(.regular, in: .capsule)
            }
        } else {
            content
                .background(
                    Theme.tile.opacity(0.94),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .strokeBorder(.white.opacity(0.5), lineWidth: 0.5)
                }
        }
    }
}

/// A single control that sits on Liquid Glass.
struct LiquidGlassButton<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            content
        }
    }
}
