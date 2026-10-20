import SwiftUI
import UIKit

/// The screen that offers a source's runs and brings the chosen ones in.
///
/// It does the talking: it asks Strava to open its sheet, it asks Health for
/// permission, and it tells the reader plainly when either cannot be done.
struct ImportSourceView: View {
    let source: ImportViewModel.Source

    @Environment(RunStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var strava = StravaService()
    @State private var health = HealthKitService()
    @State private var model: ImportViewModel?
    @State private var selected: Set<UUID> = []
    @State private var status: String?

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                ProgressView()
                    .task { await prepare() }
            }
        }
        .navigationTitle("Import from \(source.title)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model?.candidates.isEmpty == false {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { bringIn() }
                        .disabled(selected.isEmpty)
                }
            }
        }
        .alert("Import", isPresented: .constant(status != nil)) {
            Button("OK") { status = nil }
        } message: {
            Text(status ?? "")
        }
    }

    @ViewBuilder
    private func content(_ model: ImportViewModel) -> some View {
        if let reason = model.unavailableReason {
            ContentUnavailableView(
                "\(source.title) is not available",
                systemImage: "exclamationmark.triangle",
                description: Text(reason)
            )
        } else if model.isLoading {
            ProgressView("Looking for runs…")
        } else if model.candidates.isEmpty {
            ContentUnavailableView(
                "Nothing to import",
                systemImage: "tray",
                description: Text(model.message ?? model.emptyReason)
            )
        } else {
            List {
                Section {
                    ForEach(model.candidates) { candidate in
                        row(for: candidate, model: model)
                    }
                } header: {
                    Text("From \(source.title)")
                } footer: {
                    Text("Choose the runs to bring in. Your own recordings are never affected.")
                }
            }
        }
    }

    private func row(for candidate: ImportCandidate, model: ImportViewModel) -> some View {
        Button {
            guard !candidate.isAlreadyImported else { return }
            if selected.contains(candidate.id) {
                selected.remove(candidate.id)
            } else {
                selected.insert(candidate.id)
            }
        } label: {
            HStack(spacing: 12) {
                RouteSilhouette(points: candidate.run.points, breaks: candidate.run.segmentBreaks)
                    .frame(width: 46, height: 46)
                    .padding(6)
                    .background(Theme.tile, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.run.title)
                        .font(Theme.Font.value)
                        .foregroundStyle(Theme.ink)
                    Text(candidate.run.startedAt, format: .dateTime.day().month(.abbreviated).year())
                        .font(Theme.Font.label)
                        .foregroundStyle(Theme.secondary)
                    HStack(spacing: 6) {
                        Text(Format.kilometres(candidate.run.distanceMeters))
                            .font(Theme.Font.metricValue)
                            .foregroundStyle(Theme.ink)
                        Text("KM")
                            .font(Theme.Font.label)
                            .foregroundStyle(Theme.secondary)
                        Text(Format.duration(candidate.run.movingTime))
                            .font(Theme.Font.label)
                            .foregroundStyle(Theme.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if candidate.isAlreadyImported {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.secondary)
                        .accessibilityLabel("Already in your archive")
                } else {
                    Image(systemName: selected.contains(candidate.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected.contains(candidate.id) ? Theme.ink : Theme.secondary)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(candidate.isAlreadyImported)
        .accessibilityIdentifier("import-row-\(candidate.id.uuidString)")
    }

    /// Gets the source ready and loads what it has.
    private func prepare() async {
        let model = ImportViewModel(source: source, store: store, strava: strava, health: health)
        self.model = model

        switch source {
        case .strava:
            // The sheet needs a window to sit in, so the connection is made
            // from a view that is on screen.
            if case .signedOut = strava.state {
                await strava.connect(presenter: presenter)
            }
        case .health:
            await health.requestAuthorisation()
        }

        await model.load()
    }

    /// Brings the chosen runs into the archive.
    private func bringIn() {
        guard let model else { return }
        let chosen = model.candidates
            .filter { selected.contains($0.id) }
            .map(\.run)
        guard !chosen.isEmpty else { return }

        let result = store.importRuns(chosen)
        if !result.saved {
            status = "The runs could not be saved. The archive was left as it was."
            return
        }
        status = result.added == 1
            ? "One run was brought in."
            : "\(result.added) runs were brought in."
        selected.removeAll()
        Task { await model.load() }
    }

    /// The view controller the authorisation sheet can be presented from.
    @MainActor
    private var presenter: UIViewController {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
        var controller = window?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller ?? UIViewController()
    }
}
