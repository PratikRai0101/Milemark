import SwiftUI

/// The route archive.
///
/// Each cell is an individual run shown as its own route silhouette, date and
/// distance. The silhouette is the primary object: the shape of the run is what
/// people recognise, not a row of numbers.
struct ArchiveView: View {
    @Environment(RunStore.self) private var store
    @State private var selectedRun: Run?

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 11)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                if store.runs.isEmpty {
                    emptyState
                        .padding(.top, 40)
                } else {
                    if store.runs.allSatisfy({ $0.source == .imported }) {
                        sampleNotice
                            .padding(.top, 14)
                    }
                    LazyVGrid(columns: columns, spacing: 11) {
                        ForEach(store.runs) { run in
                            Button {
                                selectedRun = run
                            } label: {
                                RunTile(run: run)
                            }
                            .buttonStyle(.plain)
                            .pressable()
                        }
                    }
                    .padding(.top, 18)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .background(Theme.ground)
        .navigationTitle("MILEMARK")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("MILEMARK")
                    .font(Theme.Font.archiveTitle)
                    .foregroundStyle(Theme.ink)
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 17))
                }
                .accessibilityLabel("About Milemark")
            }
        }
        .toolbarBackground(Theme.ground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationDestination(item: $selectedRun) { run in
            ReceiptView(run: run)
        }
        .task {
            // -openReceipt opens the first stored run directly, which gives
            // screenshots and UI checks something to look at.
            if ProcessInfo.processInfo.arguments.contains("-openReceipt"),
               selectedRun == nil,
               let first = store.runs.first {
                selectedRun = first
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("SAMPLE ACTIVITIES · DEMO DATA")
                .font(Theme.Font.label)
                .foregroundStyle(Theme.secondary)
            HStack {
                Text("\(String(format: "%.1f", store.yearDistanceKilometres)) km this year")
                Spacer()
                Text(Date.now, format: .dateTime.month(.wide).year())
            }
            .font(Theme.Font.label)
            .foregroundStyle(Theme.secondary)
            .padding(.top, 14)
        }
    }

    private var sampleNotice: some View {
        Button {
            store.loadSampleActivities()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.down")
                Text("Load sample activities")
                Spacer()
                Text("9 runs")
            }
            .font(Theme.Font.label)
            .foregroundStyle(Theme.secondary)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Theme.tile, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .pressable()
        .accessibilityHint("Replaces the stored runs with fictional sample activities")
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 44))
                .foregroundStyle(Theme.secondary)
            Text("No routes yet.")
                .font(Theme.Font.screenTitle)
                .foregroundStyle(Theme.ink)
            Text("Your first run becomes your first receipt.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
            NavigationLink {
                TrackingView()
            } label: {
                Text("Record a run")
                    .font(Theme.Font.action)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.ink, in: Capsule())
                    .foregroundStyle(Theme.ground)
            }
            .buttonStyle(.plain)
            .pressable()

            Button {
                store.loadSampleActivities()
            } label: {
                Text("Load sample activities")
                    .font(Theme.Font.action)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Theme.tile, in: Capsule())
                    .foregroundStyle(Theme.ink)
            }
            .buttonStyle(.plain)
            .pressable()
        }
        .padding(.horizontal, 12)
    }
}

/// One run in the archive.
private struct RunTile: View {
    let run: Run

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(run.startedAt, format: .dateTime.weekday(.abbreviated))
                Spacer()
                Text(run.startedAt, format: .dateTime.day())
                    .accessibilityLabel(run.startedAt.formatted(.dateTime.day().month(.abbreviated)))
            }
            .font(Theme.Font.label)
            .foregroundStyle(Theme.secondary)

            RouteSilhouette(points: run.points)
                .frame(maxWidth: .infinity)
                .frame(height: 82)
                .padding(.vertical, 7)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(Format.kilometres(run.distanceMeters))
                    .font(Theme.Font.metricValue)
                Text("KM")
                    .font(Theme.Font.label)
                    .foregroundStyle(Theme.secondary)
            }
            .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Theme.tile, in: RoundedRectangle(cornerRadius: Theme.tileRadius, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            if run.isCollected {
                Circle()
                    .fill(Theme.ink)
                    .frame(width: 4, height: 4)
                    .padding(8)
                    .accessibilityLabel("Collected")
            }
        }
    }
}

/// The printed shape of a route.
struct RouteSilhouette: View {
    let points: [RoutePoint]
    var lineWidth: CGFloat = 2.1

    var body: some View {
        Canvas { context, size in
            guard points.count > 1 else { return }
            let normalised = RouteGeometry.normalisedPoints(points)
            guard let frame = RouteProjection.frame(for: normalised, in: size) else { return }
            var path = Path()
            for (index, point) in normalised.enumerated() {
                let location = RouteProjection.location(for: point, in: frame)
                if index == 0 {
                    path.move(to: location)
                } else {
                    path.addLine(to: location)
                }
            }
            context.stroke(path, with: .color(Theme.ink), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}
