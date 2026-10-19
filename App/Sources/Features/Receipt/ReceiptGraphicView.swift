import PhotosUI
import SwiftUI

/// The graphic region of the receipt.
///
/// All four treatments occupy the same fixed frame, so switching between them
/// never reflows the receipt around the user's eyes.
struct ReceiptGraphicView: View {
    let graphic: ReceiptGraphic
    let run: Run
    var photoItem: PhotosPickerItem?

    var body: some View {
        switch graphic {
        case .route:
            RouteTraceView(run: run)
        case .ascii:
            ASCIITraceView(run: run)
        case .pace:
            PaceTrendView(run: run)
        case .photo:
            PhotoPrintView(item: photoItem)
        }
    }
}

/// The recorded track, drawn as a line on a faint survey grid.
struct RouteTraceView: View {
    let run: Run
    @State private var drawProgress: CGFloat = 0

    var body: some View {
        Canvas { context, size in
            drawGrid(context: context, size: size)

            guard run.points.count > 1 else { return }
            let normalised = RouteGeometry.normalisedPoints(run.points)
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
            context.stroke(
                path,
                with: .color(Theme.paperInk),
                style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round)
            )

            // The start of the run is marked, not the end of the file.
            if let first = normalised.first {
                let start = RouteProjection.location(for: first, in: frame)
                context.fill(
                    Path(ellipseIn: CGRect(x: start.x - 3.6, y: start.y - 3.6, width: 7.2, height: 7.2)),
                    with: .color(Theme.paper)
                )
                context.stroke(
                    Path(ellipseIn: CGRect(x: start.x - 3.6, y: start.y - 3.6, width: 7.2, height: 7.2)),
                    with: .color(Theme.paperInk),
                    lineWidth: 1.8
                )
            }
        }
        .accessibilityLabel("Recorded route")
    }

    private func drawGrid(context: GraphicsContext, size: CGSize) {
        var dots = Path()
        var x: CGFloat = 9
        while x < size.width {
            var y: CGFloat = 9
            while y < size.height {
                dots.addEllipse(in: CGRect(x: x, y: y, width: 1.1, height: 1.1))
                y += 18
            }
            x += 18
        }
        context.fill(dots, with: .color(Color(white: 0.84)))
    }
}

/// The same track, printed as a field of characters.
struct ASCIITraceView: View {
    let run: Run

    private let columns = 35
    private let rows = 24

    var body: some View {
        Canvas { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Theme.graphic)
            )
            guard run.points.count > 1 else { return }
            let normalised = RouteGeometry.normalisedPoints(run.points)
            guard let frame = RouteProjection.frame(for: normalised, in: size) else { return }

            let cellWidth = size.width / CGFloat(columns)

            for row in 0..<rows {
                for column in 0..<columns {
                    let centre = CGPoint(
                        x: frame.minX + (CGFloat(column) + 0.5) / CGFloat(columns) * frame.width,
                        y: frame.maxY - (CGFloat(row) + 0.5) / CGFloat(rows) * frame.height
                    )
                    let onRoute = normalised.contains { point in
                        let location = RouteProjection.location(for: point, in: frame)
                        return hypot(location.x - centre.x, location.y - centre.y) < cellWidth * 0.7
                    }
                    guard onRoute else { continue }
                    let letters = Array("RUN")
                    let letter = letters[(column * 7 + row * 3) % letters.count]
                    let text = Text(String(letter))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.paperInk)
                    context.draw(text, at: centre)
                }
            }
        }
        .accessibilityLabel("Route drawn with letters")
    }
}

/// Pace per kilometre, drawn as a chart the reader can inspect.
struct PaceTrendView: View {
    let run: Run
    @State private var selection: Int?

    private var paces: [Double] {
        let splits = RouteGeometry.splits(run.points, breaks: run.segmentBreaks)
        guard !splits.isEmpty else { return [] }
        return splits.map(\.paceSecondsPerKm)
    }

    var body: some View {
        GeometryReader { proxy in
            let values = paces
            let maximum = values.max() ?? 1
            let minimum = values.min() ?? 0

            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    var baseline = Path()
                    baseline.move(to: CGPoint(x: 8, y: size.height - 31))
                    baseline.addLine(to: CGPoint(x: size.width - 8, y: size.height - 31))
                    context.stroke(baseline, with: .color(Color(white: 0.84)), lineWidth: 0.6)

                    for (index, value) in values.enumerated() {
                        let span = max(maximum - minimum, 1)
                        let height = 49 + (1 - (value - minimum) / span) * 84
                        let x = 8 + CGFloat(index) * 9
                        let rect = CGRect(x: x, y: size.height - 31 - height, width: 4, height: height)
                        context.fill(Path(rect), with: .color(Theme.paperInk))
                    }
                }

                if let selection, selection < values.count {
                    crosshair(values: values, selection: selection, size: proxy.size)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let index = Int((value.location.x - 8) / 9)
                        selection = min(max(index, 0), max(values.count - 1, 0))
                    }
                    .onEnded { _ in selection = nil }
            )
        }
        .accessibilityLabel("Pace per kilometre")
    }

    private func crosshair(values: [Double], selection: Int, size: CGSize) -> some View {
        let x = 8 + CGFloat(selection) * 9 + 2
        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color(white: 0.7))
                .frame(width: 1, height: size.height - 31)
                .offset(x: x)
            Text(Format.pace(values[selection]))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.paper)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.paperInk, in: Capsule())
                .offset(x: min(max(x - 28, 0), size.width - 62), y: 14)
        }
    }
}

/// A photographic print treatment.
struct PhotoPrintView: View {
    let item: PhotosPickerItem?

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Theme.graphic
            if let image {
                PhotoPrintImage(image: image)
            } else {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Theme.paperSecondary)
            }
        }
        .task(id: item) {
            image = await loadImage()
        }
        .accessibilityLabel("Photographic print treatment")
    }

    private func loadImage() async -> UIImage? {
        guard let item else { return nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
        return UIImage(data: data)
    }
}

/// The printed photograph, treated like an ink-on-paper print.
private struct PhotoPrintImage: View {
    let image: UIImage

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .grayscale(1)
            .contrast(1.6)
            .overlay {
                // A halftone screen, so the photograph reads as printed rather
                // than as a screenshot.
                Canvas { context, size in
                    var dots = Path()
                    let step: CGFloat = 3
                    var y: CGFloat = 0
                    while y < size.height {
                        var x: CGFloat = 0
                        while x < size.width {
                            dots.addEllipse(in: CGRect(x: x, y: y, width: 1.1, height: 1.1))
                            x += step
                        }
                        y += step
                    }
                    context.fill(dots, with: .color(.white.opacity(0.5)))
                }
                .blendMode(.screen)
                .allowsHitTesting(false)
            }
            .clipped()
    }
}

/// The explicit graphic chooser.
struct GraphicPicker: View {
    @Binding var graphic: ReceiptGraphic
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 8) {
            ForEach(ReceiptGraphic.allCases) { option in
                Button {
                    graphic = option
                    isPresented = false
                } label: {
                    HStack {
                        Text(option.title)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        Spacer()
                        if option == graphic {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                        }
                    }
                    .foregroundStyle(Theme.paperInk)
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(Theme.paper, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(option == graphic ? Theme.paperInk : Color(white: 0.78), lineWidth: option == graphic ? 1.6 : 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Theme.graphic.opacity(0.97))
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }
}
