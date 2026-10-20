import SwiftUI

/// The bottom edge of a printed sheet.
///
/// A receipt that has been torn off has an irregular edge, not a row of
/// perforations, so the edge here is torn: a run of shallow fibres with a
/// deeper tear in one place.
struct TornEdgeShape: Shape {
    /// A fixed sequence of offsets, so the tear is the same every time.
    private let fibres: [CGFloat] = [
        0.0, 0.5, 0.2, 0.7, 0.3, 0.0, 0.6, 0.4, 0.1, 0.8, 0.2, 0.5, 0.3, 0.7, 0.0, 0.4, 0.6, 0.1
    ]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.012))

        let step = rect.width / CGFloat(fibres.count)
        var x = rect.maxX
        for fibre in fibres {
            x -= step
            let depth = rect.height * (0.012 + fibre * 0.016)
            path.addLine(to: CGPoint(x: x, y: rect.maxY - depth))
            path.addLine(to: CGPoint(x: x + step / 2, y: rect.maxY - depth * 0.35))
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.012))
        path.closeSubpath()
        return path
    }
}
