import SwiftUI
import UIKit

/// The share preview.
///
/// This is what a runner would send. It shows the outgoing receipt exactly as
/// it will appear, and it makes the privacy choices visible rather than
/// burying them: the recorded date, time and location are always left out, the
/// route can have its ends trimmed, and the personal note can be withheld.
///
/// Trimming shortens the shape but does not make a distinctive route
/// anonymous. The copy says so.
struct SharePreviewView: View {
    let run: Run

    @State private var trimsEnds = true
    @State private var includesNote = true
    @State private var exportedFile: URL?
    @State private var isExporting = false
    @Environment(\.dismiss) private var dismiss

    private var trimmedRoute: ([RoutePoint], [Int]) {
        trimsEnds
            ? RouteGeometry.trimmed(run.points, breaks: run.segmentBreaks, fraction: 0.15)
            : (run.points, run.segmentBreaks)
    }

    private var displayedPoints: [RoutePoint] { trimmedRoute.0 }
    private var displayedBreaks: [Int] { trimmedRoute.1 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    preview
                    options
                    export
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .background(Theme.ground)
            .navigationTitle("Share preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .toolbarBackground(Theme.ground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    /// Exports the preview as a PNG and offers the system share sheet.
    private var export: some View {
        VStack(spacing: 10) {
            if let exportedFile {
                ShareLink(item: exportedFile) {
                    Label("Share receipt image", systemImage: "square.and.arrow.up")
                }
                .font(Theme.Font.action)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Theme.ink, in: Capsule())
                .foregroundStyle(Theme.ground)
            } else {
                Button {
                    isExporting = true
                    exportedFile = writeImage()
                    isExporting = false
                } label: {
                    if isExporting {
                        ProgressView().tint(Theme.ground)
                    } else {
                        Label("Prepare receipt image", systemImage: "photo")
                    }
                }
                .buttonStyle(PrimaryActionStyle())
            }

            Text("The image contains only what is shown above: the route, the three values and the optional note. No date, time or location.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 22)
    }

    /// Renders the preview card and writes it to a temporary PNG.
    ///
    /// The file lives in the temporary directory and is never uploaded
    /// anywhere by the app itself: it is handed to the system share sheet and
    /// the user decides where it goes.
    private func writeImage() -> URL? {
        let renderer = ImageRenderer(content: previewCard)
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: 340, height: 480)
        guard let image = renderer.uiImage, let data = image.pngData() else { return nil }
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "Milemark", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appending(path: "run-receipt-\(run.id.uuidString).png")
        do {
            try data.write(to: file, options: .atomic)
            return file
        } catch {
            return nil
        }
    }

    /// The card that is actually exported, with no app chrome around it.
    private var previewCard: some View {
        VStack(spacing: 0) {
            Text("A ROUTE, PRINTED")
                .font(.system(size: 11, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(Theme.paperSecondary)
                .padding(.top, 18)

            Text(run.title)
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.paperInk)
                .multilineTextAlignment(.center)
                .padding(.top, 5)

            Text("MILEMARK")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(Theme.paperSecondary)
                .padding(.top, 6)

            ShareRoutePreview(points: displayedPoints)
                .frame(height: 160)
                .padding(.vertical, 8)

            HStack {
                stat(Format.kilometres(run.distanceMeters), "KM")
                stat(Format.pace(RouteGeometry.paceSecondsPerKm(
                    distanceMeters: run.distanceMeters,
                    movingTime: run.movingTime
                )), "/KM")
                stat(Format.duration(run.elapsedTime), "TIME")
            }
            .padding(.vertical, 10)
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.paperSecondary.opacity(0.4)).frame(height: 1)
            }

            if includesNote, !run.note.isEmpty {
                Text(run.note)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.paperInk)
                    .multilineTextAlignment(.center)
                    .padding(.top, 9)
            }

            Text("A route, printed.")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.paperInk)
                .padding(.top, 9)
                .padding(.bottom, 16)
        }
        .padding(.horizontal, 18)
        .background(Theme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .stroke(Theme.rule, lineWidth: 1)
        }
    }

    private var preview: some View {
        previewCard
            .padding(.top, 8)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.paperInk)
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.paperSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var options: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $trimsEnds) {
                Text("Trim route ends")
                    .font(.system(size: 14))
            }
            .onChange(of: trimsEnds) { _, _ in
                // The prepared image no longer matches what is shown.
                exportedFile = nil
            }
            .frame(minHeight: 48)
            Divider().overlay(Theme.rule)

            Toggle(isOn: $includesNote) {
                Text("Include note")
                    .font(.system(size: 14))
            }
            .onChange(of: includesNote) { _, _ in
                exportedFile = nil
            }
            .disabled(run.note.isEmpty)
            .opacity(run.note.isEmpty ? 0.45 : 1)
            .frame(minHeight: 48)
            Divider().overlay(Theme.rule)

            Text(privacyCopy)
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)

            Text("Nothing is sent unless you choose to share it.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        }
        .padding(.top, 18)
    }

    private var privacyCopy: String {
        var copy = trimsEnds
            ? "First and last 15% removed. "
            : "Full route shown, including endpoints. "
        copy += "Recorded date, time and location omitted. "
        copy += "Your title and note may contain identifying details, and a distinctive route may still identify a place."
        return copy
    }
}

/// The route as it will be shared.
struct ShareRoutePreview: View {
    let points: [RoutePoint]
    var breaks: [Int] = []

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.graphic))
            guard points.count > 1 else { return }
            // A pause is a gap, so the route is drawn in segments.
            for segment in RouteGeometry.normalisedSegments(points, breaks: breaks) {
                guard let frame = RouteProjection.frame(for: segment, in: size, inset: 0.88) else { continue }
                var path = Path()
                for (index, point) in segment.enumerated() {
                    let location = RouteProjection.location(for: point, in: frame)
                    if index == 0 {
                        path.move(to: location)
                    } else {
                        path.addLine(to: location)
                    }
                }
                context.stroke(
                    path,
                    with: .color(Theme.paperInk),
                    style: StrokeStyle(lineWidth: 2.7, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .accessibilityLabel("Route preview")
    }
}
