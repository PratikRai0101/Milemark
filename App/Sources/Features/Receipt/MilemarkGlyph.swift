import SwiftUI

/// The mark printed at the top of every receipt.
///
/// It is a mile marker: a post with a route line running through it. The
/// reference this app was inspired by uses a pair of running figures, so this
/// is deliberately a different object in a different idiom.
struct MilemarkGlyph: View {
    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            let postWidth = width * 0.24
            let postLeft = (width - postWidth) / 2
            let capHeight = postWidth / 2
            let postBottom = height * 0.94

            // The route: a line through the post, and the trace of a run.
            var route = Path()
            route.move(to: CGPoint(x: 0, y: height * 0.58))
            route.addCurve(
                to: CGPoint(x: width, y: height * 0.4),
                control1: CGPoint(x: width * 0.3, y: height * 0.34),
                control2: CGPoint(x: width * 0.64, y: height * 0.66)
            )
            context.stroke(
                route,
                with: .color(Theme.paperInk),
                style: StrokeStyle(lineWidth: height * 0.09, lineCap: .round)
            )

            // The post: a flat base with a domed top.
            var post = Path()
            post.move(to: CGPoint(x: postLeft, y: postBottom))
            post.addLine(to: CGPoint(x: postLeft, y: capHeight))
            post.addArc(
                center: CGPoint(x: width / 2, y: capHeight),
                radius: postWidth / 2,
                startAngle: .degrees(180),
                endAngle: .degrees(0),
                clockwise: false
            )
            post.addLine(to: CGPoint(x: postLeft + postWidth, y: postBottom))
            post.closeSubpath()
            context.fill(post, with: .color(Theme.paperInk))
        }
        .frame(width: 26, height: 24)
        .accessibilityHidden(true)
    }
}
