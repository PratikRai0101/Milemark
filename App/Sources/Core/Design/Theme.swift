import SwiftUI

/// Visual tokens for the app.
///
/// The palette is deliberately narrow: a neutral grey ground, thermal-paper
/// white for receipts, near-black ink for data and a single signal colour that
/// only ever means "this run is being recorded". Dark mode keeps the paper as a
/// lit physical object rather than inverting it into a negative image.
public enum Theme {
    // MARK: - Colour

    public static let ground = Color(light: 0xEDEDEC, dark: 0x181A1A)
    public static let tile = Color(light: 0xE5E6E3, dark: 0x282B2A)
    public static let ink = Color(light: 0x191A19, dark: 0xF1F1EC)
    public static let secondary = Color(light: 0x62645F, dark: 0xB8BBB5)
    public static let rule = Color(light: 0xD5D6D2, dark: 0x444944)

    public static let paper = Color(light: 0xFFFFFF, dark: 0xDFDED6)
    public static let paperInk = Color(light: 0x191A19, dark: 0x20221F)
    public static let paperSecondary = Color(light: 0x62645F, dark: 0x52564E)
    public static let graphic = Color(light: 0xF7F7F5, dark: 0xD6D6CE)

    /// The only accent in the app. It marks the live route and the recording
    /// state, and nothing else.
    public static let signal = Color(light: 0xC5451F, dark: 0xF08A63)

    // MARK: - Shape

    public static let tileRadius: CGFloat = 13
    public static let paperInset: CGFloat = 24
    public static let paperPadding: CGFloat = 20

    // MARK: - Type

    public enum Font {
        public static let archiveTitle = SwiftUI.Font.system(size: 28, weight: .bold, design: .monospaced)
        public static let screenTitle = SwiftUI.Font.system(size: 22, weight: .bold, design: .monospaced)
        public static let metricValue = SwiftUI.Font.system(size: 17, weight: .bold, design: .monospaced)
        public static let liveDistance = SwiftUI.Font.system(size: 56, weight: .bold, design: .monospaced)
        public static let body = SwiftUI.Font.system(size: 17, weight: .regular, design: .monospaced)
        public static let label = SwiftUI.Font.system(size: 11, weight: .regular, design: .monospaced)
        public static let labelStrong = SwiftUI.Font.system(size: 11, weight: .semibold, design: .monospaced)
        public static let action = SwiftUI.Font.system(size: 15, weight: .semibold)
    }
}

public extension Color {
    /// Builds a colour that resolves per colour scheme, so tokens stay in one
    /// place instead of being duplicated in every view.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

public extension View {
    /// Press feedback: a quick compress on touch-down that springs back.
    func pressable(_ scale: CGFloat = 0.97) -> some View {
        buttonStyle(PressableButtonStyle(scale: scale))
    }
}

private struct PressableButtonStyle: ButtonStyle {
    let scale: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.spring(duration: 0.22, bounce: 0), value: configuration.isPressed)
    }
}
