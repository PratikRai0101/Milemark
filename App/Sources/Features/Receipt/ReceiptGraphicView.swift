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
///
/// The whole area is printed in a pale character field, and the characters
/// the route passes through are printed in full ink. The shape of the run is
/// therefore readable at a glance, the way a printed map is.
struct ASCIITraceView: View {
    let run: Run

    private let columns = 33
    private let rows = 22

    var body: some View {
        Canvas { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Theme.graphic)
            )
            guard run.points.count > 1 else { return }
            let normalised = RouteGeometry.normalisedPoints(run.points)
            guard let frame = RouteProjection.frame(for: normalised, in: size, inset: 0.86) else { return }

            let cellWidth = size.width / CGFloat(columns)
            let cellHeight = size.height / CGFloat(rows)
            let letters = Array("RUN")
            // The printed field reaches a little beyond the route, so the map
            // has an edge rather than bleeding into the paper.
            let field = frame.insetBy(dx: -cellWidth * 1.6, dy: -cellHeight * 1.6)

            for row in 0..<rows {
                for column in 0..<columns {
                    let centre = CGPoint(
                        x: (CGFloat(column) + 0.5) * cellWidth,
                        y: (CGFloat(row) + 0.5) * cellHeight
                    )
                    // The whole area the route occupies is printed in a pale
                    // field, and the route is printed over it in full ink, so
                    // the shape reads the way a printed map does.
                    let inField = field.contains(centre)
                    guard inField else { continue }

                    let onRoute = normalised.contains { point in
                        let location = RouteProjection.location(for: point, in: frame)
                        return hypot(location.x - centre.x, location.y - centre.y) < cellWidth * 0.95
                    }
                    let letter = letters[(column * 7 + row * 3) % letters.count]
                    let text = Text(String(letter))
                        .font(.system(size: min(cellWidth, cellHeight) * 0.92, weight: onRoute ? .semibold : .regular, design: .monospaced))
                        .foregroundStyle(onRoute ? Theme.paperInk : Theme.paperSecondary.opacity(0.28))
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

    private var splits: [RouteGeometry.Split] {
        RouteGeometry.splits(run.points, breaks: run.segmentBreaks)
    }

    var body: some View {
        GeometryReader { proxy in
            let values = splits.map(\.paceSecondsPerKm)
            let maximum = values.max() ?? 1
            let minimum = values.min() ?? 0
            let baseline = proxy.size.height - 34
            let spacing = values.isEmpty ? 0 : min((proxy.size.width - 20) / CGFloat(values.count), 38)
            let barWidth = min(spacing * 0.52, 18)

            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    var rule = Path()
                    rule.move(to: CGPoint(x: 8, y: baseline))
                    rule.addLine(to: CGPoint(x: size.width - 8, y: baseline))
                    context.stroke(rule, with: .color(Color(white: 0.84)), lineWidth: 0.6)

                    for (index, value) in values.enumerated() {
                        let span = max(maximum - minimum, 1)
                        let height = 40 + (1 - (value - minimum) / span) * (baseline - 56)
                        let x = 10 + CGFloat(index) * spacing
                        let rect = CGRect(x: x, y: baseline - height, width: barWidth, height: height)
                        context.fill(Path(rect), with: .color(Theme.paperInk))
                    }

                    // The axis reads where the run started and ended.
                    let start = Text("0 KM")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.paperSecondary)
                    context.draw(start, at: CGPoint(x: 8, y: baseline + 16), anchor: .leading)

                    let end = Text("\(run.distanceMeters / 1000, specifier: "%.1f") KM")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.paperSecondary)
                    context.draw(end, at: CGPoint(x: size.width - 8, y: baseline + 16), anchor: .trailing)
                }

                if let selection, selection < values.count {
                    crosshair(
                        values: values,
                        selection: selection,
                        size: proxy.size,
                        spacing: spacing,
                        barWidth: barWidth,
                        baseline: baseline
                    )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !values.isEmpty else { return }
                        let index = Int((value.location.x - 10) / max(spacing, 1))
                        selection = min(max(index, 0), values.count - 1)
                    }
                    .onEnded { _ in selection = nil }
            )
        }
        .accessibilityLabel("Pace per kilometre")
    }

    private func crosshair(
        values: [Double],
        selection: Int,
        size: CGSize,
        spacing: CGFloat,
        barWidth: CGFloat,
        baseline: CGFloat
    ) -> some View {
        let x = 10 + CGFloat(selection) * spacing + barWidth / 2
        let fastest = values.enumerated().min { $0.element < $1.element }?.offset
        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color(white: 0.72))
                .frame(width: 1, height: baseline - 4)
                .offset(x: x)
            Text(Format.pace(values[selection]))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.paper)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.paperInk, in: Capsule())
                .offset(x: min(max(x - 30, 0), size.width - 62), y: 12)
            if let fastest, fastest == selection {
                Text("FASTEST")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.paperSecondary)
                    .offset(x: min(max(x - 22, 0), size.width - 44), y: baseline + 4)
            }
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
                .accessibilityIdentifier("graphic-\(option.rawValue)")
            }
        }
        .padding(10)
        .background(Theme.graphic.opacity(0.97))
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }
}
