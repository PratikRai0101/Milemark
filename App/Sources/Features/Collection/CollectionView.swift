import SwiftUI

/// The collection of kept receipts.
///
/// Saving a receipt puts it here. The collection uses the same language as
/// the archive — a route, a date, a distance — because a kept receipt is a
/// route someone chose to keep, not a statistic.
struct CollectionView: View {
    @Environment(RunStore.self) private var store

    private var collected: [Run] {
        store.runs.filter(\.isCollected)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if collected.isEmpty {
                    emptyState
                        .padding(.top, 60)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 104), spacing: 11)],
                        spacing: 11
                    ) {
                        ForEach(collected) { run in
                            NavigationLink {
                                ReceiptView(run: run)
                            } label: {
                                CollectedTile(run: run)
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
        .navigationTitle("Kept")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.ground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.secondary)
            Text("Nothing kept yet.")
                .font(Theme.Font.screenTitle)
                .foregroundStyle(Theme.ink)
            Text("Open a receipt and keep it, and it stays here.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 12)
    }
}

/// A kept receipt, shown as its route.
private struct CollectedTile: View {
    let run: Run

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(run.startedAt, format: .dateTime.weekday(.abbreviated))
                Spacer()
                Text(run.startedAt, format: .dateTime.day())
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
    }
}
