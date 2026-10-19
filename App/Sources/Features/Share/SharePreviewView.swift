import SwiftUI

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
    @Environment(\.dismiss) private var dismiss

    private var displayedPoints: [RoutePoint] {
        trimsEnds ? RouteGeometry.trimmed(run.points, fraction: 0.15) : run.points
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    preview
                    options
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

    private var preview: some View {
        VStack(spacing: 0) {
            Text("A ROUTE WORTH KEEPING")
                .font(.system(size: 11, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(Theme.paperSecondary)
                .padding(.top, 18)

            Text(run.title)
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.paperInk)
                .multilineTextAlignment(.center)
                .padding(.top, 5)

            Text("RUN RECEIPT")
                .font(.system(size: 11, design: .monospaced))
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

            Text("A route worth keeping.")
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
            .frame(minHeight: 48)
            Divider().overlay(Theme.rule)

            Toggle(isOn: $includesNote) {
                Text("Include note")
                    .font(.system(size: 14))
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

            Text("Preview only. No file is exported or sent.")
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

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.graphic))
            guard points.count > 1 else { return }
            let normalised = RouteGeometry.normalisedPoints(points)
            guard let frame = RouteProjection.frame(for: normalised, in: size, inset: 0.88) else { return }
            var path = Path()
            for (index, point) in normalised.enumerated() {
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
        .accessibilityLabel("Route preview")
    }
}
