import CoreGraphics
import Foundation

/// Fits a normalised route into a rectangle without distorting it.
///
/// The same projection is used by the archive silhouette, the printed route
/// trace and the share preview, so a run looks like the same shape in every
/// place it appears.
public enum RouteProjection {
    /// Returns the rectangle that a unit-square route should be drawn into.
    ///
    /// - Parameters:
    ///   - points: normalised points, each in the unit square.
    ///   - size: the space available.
    ///   - inset: fraction of the size kept clear around the route.
    public static func frame(for points: [CGPoint], in size: CGSize, inset: CGFloat = 0.92) -> CGRect? {
        guard let first = points.first else { return nil }
        var minX = first.x
        var maxX = first.x
        var minY = first.y
        var maxY = first.y
        for point in points {
            minX = Swift.min(minX, point.x)
            maxX = Swift.max(maxX, point.x)
            minY = Swift.min(minY, point.y)
            maxY = Swift.max(maxY, point.y)
        }
        let width = Swift.max(maxX - minX, 0.0001)
        let height = Swift.max(maxY - minY, 0.0001)
        let scale = Swift.min(size.width / width, size.height / height) * inset
        return CGRect(
            x: (size.width - width * scale) / 2,
            y: (size.height - height * scale) / 2,
            width: width * scale,
            height: height * scale
        )
    }

    /// Maps a normalised point into a frame, flipping the vertical axis so
    /// north is up.
    public static func location(for point: CGPoint, in frame: CGRect) -> CGPoint {
        CGPoint(
            x: frame.minX + point.x * frame.width,
            y: frame.maxY - point.y * frame.height
        )
    }
}
