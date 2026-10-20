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
///
/// The system material is behind a compiler check as well as a runtime one.
/// The API only exists in the SDK that shipped with Swift 6.2, so an older
/// toolchain cannot even compile a reference to it, however carefully it is
/// marked as available.
/// The shape of a glass surface.
///
/// A row of controls is a capsule. A column of controls is a rounded
/// rectangle, because a capsule around three stacked buttons would be mostly
/// empty glass at the top and bottom.
public enum GlassShape {
    case capsule
    case roundedRect(cornerRadius: CGFloat)

    /// The shape as something the system can draw.
    var anyShape: AnyShape {
        switch self {
        case .capsule:
            AnyShape(Capsule())
        case .roundedRect(let radius):
            AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }
}

public struct LiquidGlassBar<Content: View>: View {
    let shape: GlassShape
    @ViewBuilder var content: Content

    public init(shape: GlassShape = .capsule, @ViewBuilder content: () -> Content) {
        self.shape = shape
        self.content = content()
    }

    public var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 8) {
                content
                    .glassEffect(.regular, in: shape.anyShape)
            }
        } else {
            flatBar
        }
        #else
        flatBar
        #endif
    }

    /// The bar on systems without the system material.
    private var flatBar: some View {
        content
            .background(
                Theme.tile.opacity(0.94),
                in: shape.anyShape
            )
            .overlay {
                shape.anyShape
                    .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
            }
    }
}

/// A single control that sits on Liquid Glass.
public struct LiquidGlassButton<Content: View>: View {
    @ViewBuilder var content: Content

    public var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            content
        }
        #else
        content
        #endif
    }
}
