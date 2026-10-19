import SwiftUI

/// The review step between finishing a run and printing its receipt.
///
/// The numbers are fixed by the recording: this screen only lets the runner
/// name the run and add a note. Nothing is uploaded and nothing is committed
/// until the receipt is printed.
struct ReviewSheet: View {
    @Binding var title: String
    @Binding var note: String

    let distanceKilometres: Double
    let elapsed: TimeInterval
    let pace: Double?
    let onCancel: () -> Void
    let onPrint: (Run) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("KALLANG RIVERSIDE · SAMPLE RUN")
                        .font(Theme.Font.label)
                        .foregroundStyle(Theme.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(String(format: "%.2f", distanceKilometres))
                            .font(.system(size: 43, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.numericText())
                        Text("km")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.secondary)
                    }
                    .padding(.top, 6)

                    HStack {
                        fact(Format.duration(elapsed), "Elapsed time")
                        Spacer()
                        fact(Format.pace(pace), "Avg pace /km")
                    }
                    .padding(.vertical, 16)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Theme.rule).frame(height: 1)
                    }

                    Text("Run title")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondary)
                        .padding(.top, 16)
                    TextField("Run title", text: $title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .padding(12)
                        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Theme.rule, lineWidth: 1)
                        }

                    Text("Note · optional")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondary)
                        .padding(.top, 14)
                    TextField("Something worth remembering.", text: $note, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(2...4)
                        .font(.system(size: 16))
                        .padding(12)
                        .frame(minHeight: 76, alignment: .topLeading)
                        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Theme.rule, lineWidth: 1)
                        }

                    Text("Your numbers and route stay the same on the receipt. Nothing is uploaded.")
                        .font(Theme.Font.label)
                        .foregroundStyle(Theme.secondary)
                        .padding(.top, 10)

                    Button {
                        onPrint(makeRun())
                    } label: {
                        Label("Print receipt", systemImage: "arrow.down")
                    }
                    .buttonStyle(PrimaryActionStyle())
                    .padding(.top, 24)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .background(Theme.ground)
            .navigationTitle("Review run")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
            }
            .toolbarBackground(Theme.ground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private func fact(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(Theme.Font.label)
                .foregroundStyle(Theme.secondary)
        }
    }

    private func makeRun() -> Run {
        Run(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Outdoor run" : title,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            startedAt: .now.addingTimeInterval(-elapsed),
            endedAt: .now,
            elapsedTime: elapsed,
            movingTime: elapsed,
            distanceMeters: distanceKilometres * 1000,
            elevationGainMeters: 0,
            points: [],
            isCollected: false,
            source: .recorded
        )
    }
}
