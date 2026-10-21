import MapKit
import UIKit

/// The marks the app draws on the map itself.
///
/// Apple's `MKMarkerAnnotationView` is a system pin, and a system pin says
/// "here is a place". These say "here is a run": the start is a surveyor's
/// mark, and the runner is a filled dot ringed in white so that it can be
/// read against a pale map as well as a dark one.
final class MilemarkAnnotationView: MKAnnotationView {
    private let kind: MilemarkPointAnnotation.Kind

    init(kind: MilemarkPointAnnotation.Kind, annotation: MKAnnotation?, reuseIdentifier: String?) {
        self.kind = kind
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        isOpaque = false
        // The mark is a fixed size: it is a symbol, not a label.
        frame.size = CGSize(width: 22, height: 22)
        // It should not swallow a tap meant for the map.
        isUserInteractionEnabled = false
        setContentHuggingPriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width / 2 - 1

        switch kind {
        case .start:
            // A white disc inside a dark ring: a mark that reads as a point
            // on a map rather than as a place to go.
            let ring = UIBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
            UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 0.85).setStroke()
            ring.lineWidth = 2
            ring.stroke()

            let disc = UIBezierPath(ovalIn: rect.insetBy(dx: 4, dy: 4))
            UIColor.white.setFill()
            disc.fill()

        case .runner:
            // A dark ring under a filled dot, and a white ring over it, so
            // the runner is legible on any basemap.
            let shadow = UIBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 1.5))
            UIColor(red: 0, green: 0, blue: 0, alpha: 0.25).setFill()
            shadow.fill()

            let dot = UIBezierPath(ovalIn: rect.insetBy(dx: 3, dy: 3))
            UIColor(red: 0.77, green: 0.32, blue: 0.12, alpha: 1).setFill()
            dot.fill()

            let ring = UIBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
            UIColor.white.setStroke()
            ring.lineWidth = 2
            ring.stroke()

            let centreDot = UIBezierPath(ovalIn: CGRect(
                x: centre.x - 1.5, y: centre.y - 1.5, width: 3, height: 3
            ))
            UIColor.white.setFill()
            centreDot.fill()
        }
    }
}
