import SwiftUI

@main
struct MilemarkApp: App {
    @State private var store = RunStore()
    @State private var recorder = RunRecorder()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(recorder)
                .tint(Theme.ink)
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
        }
        .toolbarBackground(Theme.ground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .task {
            // -showRecord opens the tracking screen, for screenshots and UI
            // checks that need to start there.
            if ProcessInfo.processInfo.arguments.contains("-showRecord") {
                selection = .record
            }
        }
    }
}
