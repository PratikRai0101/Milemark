import CoreHaptics
import UIKit

/// The app's haptics.
///
/// Haptics are half of what a tap feels like, so they are treated as part of
/// the interface rather than as an extra. The rules are simple: a tap is
/// answered, a change of state is confirmed, and a long operation like the
/// paper feeding out is felt as it happens rather than announced at the end.
///
/// Nothing here is loud. There is no haptic on every press, and no vibration
/// while a run is being recorded.
@MainActor
final class Haptics {
    static let shared = Haptics()

    /// The impact weight used for a button landing.
    enum Weight {
        case light
        case medium
        case rigid
    }

    private var engine: CHHapticEngine?
    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    private init() {
        prepareEngine()
    }

    private func prepareEngine() {
        guard supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = true
            engine.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            try engine.start()
            self.engine = engine
        } catch {
            // A device without a haptic engine still gets the system
            // fallbacks below.
            engine = nil
        }
    }

    // MARK: - Feedback

    /// A light tick, for a selection that changed.
    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    /// A button landing.
    func impact(_ weight: Weight = .light) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        switch weight {
        case .light: style = .light
        case .medium: style = .medium
        case .rigid: style = .rigid
        }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Something finished the way it should.
    func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    /// Something did not finish the way it should.
    func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    /// The paper feeding out of the tray.
    ///
    /// A run of soft transients along the length of the feed, so the receipt
    /// feels like it is being printed rather than simply appearing.
    func printTicks(over duration: TimeInterval, count: Int = 12) {
        guard supportsHaptics, let engine else { return }
        var events: [CHHapticEvent] = []
        for index in 0..<max(count, 1) {
            let time = duration * Double(index) / Double(max(count, 1))
            events.append(
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.22),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.35)
                    ],
                    relativeTime: time
                )
            )
        }
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try engine.start()
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // A failed pattern is not worth a crash.
        }
    }

    /// Stops any pattern that is still playing.
    func stop() {
        engine?.stop()
    }
}
