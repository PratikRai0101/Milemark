import PhotosUI
import SwiftUI

/// The ways a photograph can be printed on the receipt.
///
/// The reference app this was inspired by prints the same photograph several
/// different ways, and dissolves between them. These are our own versions of
/// that idea: a dot screen, an ordered dither, and a hard two-tone poster.
enum PhotoTreatment: String, CaseIterable, Identifiable {
    case halftone
    case dither
    case poster

    var id: String { rawValue }

    var title: String {
        switch self {
        case .halftone: "HALFTONE"
        case .dither: "DITHER"
        case .poster: "POSTER"
        }
    }
}

/// A photograph printed on the receipt.
///
/// The image is sampled down to a grid of dots, and each dot is drawn
/// according to the tone under it. The grid is then laid down row by row, so
/// the picture is printed rather than simply shown.
struct PhotoPrintView: View {
    let item: PhotosPickerItem?
    var treatment: PhotoTreatment = .halftone

    @State private var image: UIImage?
    @State private var tones: [Double] = []
    @State private var columns = 0
    @State private var rows = 0
    @State private var printed = 0.0

    /// The size of the dot grid. Fine enough to read as a picture, coarse
    /// enough to print.
    private let gridWidth = 74
    private let gridHeight = 56

    var body: some View {
        ZStack {
            Theme.graphic
            if let image, !tones.isEmpty {
                Canvas { context, size in
                    draw(context: context, size: size)
                }
            } else {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Theme.paperSecondary)
            }
        }
        .task(id: item) {
            // The loaded image is used directly: reading the state back here
            // would still return the previous value.
            guard let loaded = await loadImage() else { return }
            image = loaded
            sample(loaded)
        }
        .task(id: treatment) {
            printed = 0
            withAnimation(.linear(duration: 0.45)) { printed = 1 }
        }
        .accessibilityLabel("Photographic print treatment")
    }

    // MARK: - Drawing

    private func draw(context: GraphicsContext, size: CGSize) {
        guard columns > 0, rows > 0 else { return }
        let cellWidth = size.width / CGFloat(columns)
        let cellHeight = size.height / CGFloat(rows)
        // The row that is being printed right now, drawn slightly darker so
        // the ink looks like it is being laid down.
        let currentRow = Int(printed * CGFloat(rows))

        for row in 0..<rows {
            let rowProgress = (CGFloat(row) + 1) / CGFloat(rows)
            guard rowProgress <= printed else { break }
            let isCurrent = row == currentRow

            for column in 0..<columns {
                let tone = tones[row * columns + column]
                let centre = CGPoint(
                    x: (CGFloat(column) + 0.5) * cellWidth,
                    y: (CGFloat(rows) - CGFloat(row) - 0.5) * cellHeight
                )

                switch treatment {
                case .halftone:
                    // A dot screen: the darker the tone, the larger the dot.
                    let darkness = 1 - tone
                    guard darkness > 0.04 else { continue }
                    let radius = min(cellWidth, cellHeight) * 0.5 * sqrt(darkness)
                    let dot = Path(ellipseIn: CGRect(
                        x: centre.x - radius,
                        y: centre.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    ))
                    context.fill(dot, with: .color(Theme.paperInk.opacity(isCurrent ? 1 : 0.92)))

                case .dither:
                    // An ordered dither: a fixed threshold pattern decides
                    // whether each cell is inked.
                    let threshold = (Self.bayer[row % 4][column % 4] + 0.5) / 16
                    guard tone > threshold else { continue }
                    let inset = min(cellWidth, cellHeight) * 0.12
                    let square = Path(CGRect(
                        x: centre.x - cellWidth / 2 + inset,
                        y: centre.y - cellHeight / 2 + inset,
                        width: cellWidth - inset * 2,
                        height: cellHeight - inset * 2
                    ))
                    context.fill(square, with: .color(Theme.paperInk.opacity(isCurrent ? 1 : 0.9)))

                case .poster:
                    // A hard two-tone: ink or nothing.
                    let adjusted = pow(tone, 0.75)
                    guard adjusted > 0.52 else { continue }
                    let square = Path(CGRect(
                        x: centre.x - cellWidth / 2,
                        y: centre.y - cellHeight / 2,
                        width: cellWidth,
                        height: cellHeight
                    ))
                    context.fill(square, with: .color(Theme.paperInk.opacity(isCurrent ? 1 : 0.88)))
                }
            }
        }
    }

    /// The ordered dither threshold pattern.
    private static let bayer: [[Double]] = [
        [0, 8, 2, 10],
        [12, 4, 14, 6],
        [3, 11, 1, 9],
        [15, 7, 13, 5]
    ]

    // MARK: - Image

    private func loadImage() async -> UIImage? {
        if let item {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
            return UIImage(data: data)
        }
        // -demoPhoto loads the bundled sample picture, so the treatments can be
        // seen without picking one from the library.
        guard ProcessInfo.processInfo.arguments.contains("-demoPhoto") else { return nil }
        guard let url = Bundle.main.url(forResource: "SamplePhoto", withExtension: "jpg") else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }

    /// Samples the image down to a grid of tones.
    private func sample(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        var pixels = [UInt8](repeating: 0, count: gridWidth * gridHeight)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: gridWidth,
                height: gridHeight,
                bitsPerComponent: 8,
                bytesPerRow: gridWidth,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            context.interpolationQuality = .low
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: gridWidth, height: gridHeight))
            return true
        }
        guard drawn else { return }
        columns = gridWidth
        rows = gridHeight
        tones = pixels.map { Double($0) / 255 }
    }
}
