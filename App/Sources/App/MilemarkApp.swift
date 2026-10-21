import SwiftUI

@main
struct MilemarkApp: App {
    @State private var store = RunStore()
    @State private var recorder = RunRecorder()
    @State private var preferences = Preferences()

    var body: some Scene {
        WindowGroup {
            root
                .environment(store)
                .environment(recorder)
                .environment(preferences)
                .tint(Theme.ink)
        }
    }

    /// The app's root, with the text size overridden when a launch argument
    /// asks for it.
    ///
    /// The override is only applied when it was asked for. Applying it
    /// unconditionally would replace the reader's own setting with a fixed
    /// one, which is the opposite of what Dynamic Type is for.
    @ViewBuilder
    private var root: some View {
        if let forced = LaunchArguments.dynamicTypeSize {
            RootView()
                .dynamicTypeSize(forced)
        } else {
            RootView()
        }
    }
}

/// The launch arguments the app understands.
///
/// They exist so that a screenshot or a UI check can be taken at a particular
/// text size, without depending on whatever the simulator's own settings
/// happen to be.
enum LaunchArguments {
    /// The text size to force, if one was asked for.
    ///
    /// `-dynamicTypeSize=accessibility3` sets the accessibility3 size, and so
    /// on. Without it the app follows the reader's own setting.
    static var dynamicTypeSize: DynamicTypeSize? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let raw = arguments
            .first(where: { $0.hasPrefix("-dynamicTypeSize=") })?
            .replacingOccurrences(of: "-dynamicTypeSize=", with: "")
        else { return nil }

        switch raw {
        case "large": return .large
        case "xLarge": return .xLarge
        case "xxLarge": return .xxLarge
        case "xxxLarge": return .xxxLarge
        case "accessibility1": return .accessibility1
        case "accessibility2": return .accessibility2
        case "accessibility3": return .accessibility3
        case "accessibility4": return .accessibility4
        case "accessibility5": return .accessibility5
        default: return nil
        }
    }
}

/// The app's entry point.
///
/// The default tab is Runs: the archive of routes is the product, not a
/// dashboard of numbers. Recording is one tap away.
struct RootView: View {
    @Environment(RunStore.self) private var store
    @State private var selection: Tab = .runs

    enum Tab: Hashable {
        case runs
        case record
        case kept

        init?(rawValue: String) {
            switch rawValue {
            case "runs": self = .runs
            case "record": self = .record
            case "kept": self = .kept
            default: return nil
            }
        }
    }

    var body: some View {
        @Bindable var store = store
        TabView(selection: $selection) {
            NavigationStack {
                ArchiveView()
            }
            .tabItem { Label("Runs", systemImage: "square.grid.2x2") }
            .tag(Tab.runs)

            NavigationStack {
                TrackingView()
            }
            .tabItem { Label("Record", systemImage: "figure.run") }
            .tag(Tab.record)

            NavigationStack {
                CollectionView()
            }
            .tabItem { Label("Kept", systemImage: "tray") }
            .tag(Tab.kept)
        }
        .toolbarBackground(Theme.ground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .task {
            // -tab=runs|record|kept opens a particular tab, for screenshots
            // and UI checks that need to start there.
            if let requested = ProcessInfo.processInfo.arguments
                .first(where: { $0.hasPrefix("-tab=") })?
                .replacingOccurrences(of: "-tab=", with: ""),
               let tab = Tab(rawValue: requested) {
                selection = tab
            } else if ProcessInfo.processInfo.arguments.contains("-openReview") {
                // The review step lives on the Record tab.
                selection = .record
            }
        }
    }
}
