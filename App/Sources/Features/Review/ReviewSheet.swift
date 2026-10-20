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
    /// Returns the finished run. The route is built by the caller, which owns
    /// the recording, so no geometry is lost on the way to the receipt.
    let onPrint: (String, String) -> Run

    @Environment(\.dismiss) private var dismiss
    /// The distance is the headline of the review, so it scales.
    @ScaledMetric(relativeTo: .largeTitle) private var reviewDistanceSize: CGFloat = 43

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("KALLANG RIVERSIDE · SAMPLE RUN")
                        .font(Theme.Font.label)
                        .foregroundStyle(Theme.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(String(format: "%.2f", distanceKilometres))
                            .font(.system(size: reviewDistanceSize, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.numericText())
                        Text("km")
                            .font(.body)
                            .foregroundStyle(Theme.secondary)
                    }
                    .padding(.top, 6)

                    // The two facts sit side by side when there is room. When
                    // there is not, they become a column: side by side, the
                    // labels break mid-word.
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            fact(Format.duration(elapsed), "Elapsed time")
                            Spacer()
                            fact(Format.pace(pace), "Avg pace /km")
                        }
                        VStack(alignment: .leading, spacing: 14) {
                            fact(Format.duration(elapsed), "Elapsed time")
                            fact(Format.pace(pace), "Avg pace /km")
                        }
                    }
                    .padding(.vertical, 16)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Theme.rule).frame(height: 1)
                    }

                    Text("Run title")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondary)
                        .padding(.top, 16)
                    TextField("Run title", text: $title)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .padding(12)
                        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Theme.rule, lineWidth: 1)
                        }

                    Text("Note · optional")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondary)
                        .padding(.top, 14)
                    TextField("Something worth remembering.", text: $note, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(2...4)
                        .font(.body)
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
                        _ = onPrint(title, note)
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
                .font(Theme.Font.value)
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(Theme.Font.label)
                .foregroundStyle(Theme.secondary)
                // The label keeps its words whole. A label broken across two
                // lines mid-word is not readable.
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
