import SwiftUI

/// Visual tokens for the app.
///
/// The palette is deliberately narrow: a neutral grey ground, thermal-paper
/// white for receipts, near-black ink for data and a single signal colour that
/// only ever means "this run is being recorded". Dark mode keeps the paper as a
/// lit physical object rather than inverting it into a negative image.
///
/// The type is built from **text styles**, so it follows the reader's
/// Dynamic Type setting. A receipt that ignored the setting would be a receipt
/// some people could not read.
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
    //
    // These are text styles rather than fixed sizes, so everything scales
    // with the reader's setting. The monospaced design is kept: the data is
    // the point of the receipt, and a receipt set in proportional figures
    // reads like a form rather than a record.

    public enum Font {
        /// The masthead of the archive.
        public static let archiveTitle = SwiftUI.Font.system(.title, design: .monospaced).weight(.bold)
        /// A screen's title.
        public static let screenTitle = SwiftUI.Font.system(.title2, design: .monospaced).weight(.bold)
        /// The name of the run, on the paper.
        public static let paperTitle = SwiftUI.Font.system(.title3, design: .monospaced).weight(.bold)
        /// A number on the paper.
        public static let metricValue = SwiftUI.Font.system(.headline, design: .monospaced).weight(.bold)
        /// A number in the app, outside the paper.
        public static let value = SwiftUI.Font.system(.headline, design: .monospaced).weight(.semibold)
        /// Running text in the app's own voice.
        public static let body = SwiftUI.Font.system(.body, design: .monospaced)
        /// A label, such as "Elapsed time".
        public static let label = SwiftUI.Font.system(.caption2, design: .monospaced)
        /// A label that carries more weight.
        public static let labelStrong = SwiftUI.Font.system(.caption2, design: .monospaced).weight(.semibold)
        /// A footnote on the paper.
        public static let footnote = SwiftUI.Font.system(.caption, design: .monospaced)
        /// A button.
        public static let action = SwiftUI.Font.system(.subheadline, design: .default).weight(.semibold)
    }

    // MARK: - Layout

    /// The narrowest a card may be before it is worth putting two side by
    /// side.
    ///
    /// A 104pt card is three across on a phone. At the accessibility text
    /// sizes its own contents no longer fit inside it, so the cards become
    /// one across and each gets the full width.
    public static func cardMinimum(for size: DynamicTypeSize) -> CGFloat {
        size.isAccessibilitySize ? 240 : 104
    }

    /// How many columns the receipt's statistics are laid out in.
    ///
    /// At the larger text sizes three columns of figures do not fit, so the
    /// receipt becomes two columns rather than shrinking the numbers back down
    /// to something unreadable.
    public static func receiptColumns(for size: DynamicTypeSize) -> Int {
        size.isAccessibilitySize ? 2 : 3
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
