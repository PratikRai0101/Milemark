import SwiftUI

/// About and settings.
///
/// The app has no account and no server, so this screen exists to say so
/// plainly rather than to hide settings behind them.
struct SettingsView: View {
    @Environment(RunStore.self) private var store
    @Environment(RunRecorder.self) private var recorder
    @Environment(\.dismiss) private var dismiss

    @State private var showsDeleteConfirmation = false

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
    }
}
