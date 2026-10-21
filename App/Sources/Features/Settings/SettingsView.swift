import SwiftUI

/// About and settings.
///
/// The app has no account and no server, so this screen exists to say so
/// plainly rather than to hide settings behind them.
struct SettingsView: View {
    @Environment(RunStore.self) private var store
    @Environment(RunRecorder.self) private var recorder
    @Environment(Preferences.self) private var preferences
    @Environment(\.dismiss) private var dismiss

    @State private var showsDeleteConfirmation = false
    @State private var importSource: ImportViewModel.Source?

    var body: some View {
        List {
            Section {
                LabeledContent("Runs stored", value: "\(store.runs.count)")
                LabeledContent("Distance this year", value: "\(String(format: "%.1f", store.yearDistanceKilometres)) km")
                LabeledContent("Collected", value: "\(store.runs.filter(\.isCollected).count)")
            } header: {
                Text("On this device")
            } footer: {
                Text("Runs are saved locally on this iPhone. There is no account and no server.")
            }

            Section {
                Picker("Map style", selection: Binding(
                    get: { preferences.mapStyle },
                    set: { preferences.mapStyle = $0 }
                )) {
                    ForEach(MapStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("map-style-picker")

                Text(preferences.mapStyle.explanation)
                    .font(Theme.Font.footnote)
                    .foregroundStyle(Theme.secondary)
            } header: {
                Text("Map")
            } footer: {
                Text("Milemark holds Apple's map back and draws the route over it. Standard leaves the map as Apple draws it.")
            }

            Section {
                Button {
                    recorder.requestAuthorization()
                } label: {
                    Label("Allow location access", systemImage: "location")
                }
                Button {
                    recorder.requestBackgroundAuthorization()
                } label: {
                    Label("Keep recording in the background", systemImage: "lock.clock")
                }
            } header: {
                Text("Location")
            } footer: {
                Text("Background recording needs the Always permission so a run keeps logging while the screen is locked.")
            }

            Section {
                Button {
                    importSource = .strava
                } label: {
                    Label("Import from Strava", systemImage: "figure.run.circle")
                }
                .accessibilityIdentifier("import-strava")

                Button {
                    importSource = .health
                } label: {
                    Label("Import from Health", systemImage: "heart.text.square")
                }
                .accessibilityIdentifier("import-health")
            } header: {
                Text("Import")
            } footer: {
                Text("Bring in runs recorded by another app. Imported runs keep their own numbers and are marked as imported in the archive.")
            }

            Section {
                Button(role: .destructive) {
                    showsDeleteConfirmation = true
                } label: {
                    Label("Delete all runs", systemImage: "trash")
                }
            } footer: {
                Text("Milemark is a prototype. MILEMARK is a working title, not a settled brand.")
            }
        }
        .navigationTitle("Milemark")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete every stored run?", isPresented: $showsDeleteConfirmation) {
            Button("Delete all runs", role: .destructive) {
                for run in store.runs {
                    store.delete(runID: run.id)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .navigationDestination(item: $importSource) { source in
            ImportSourceView(source: source)
        }
        .task {
            // -openImport=strava|health opens one of the import screens
            // directly, so a screenshot or a UI check can reach it without
            // tapping through.
            if let requested = ProcessInfo.processInfo.arguments
                .first(where: { $0.hasPrefix("-openImport=") })?
                .replacingOccurrences(of: "-openImport=", with: ""),
               let source = ImportViewModel.Source(rawValue: requested) {
                importSource = source
            }
        }
    }
}
