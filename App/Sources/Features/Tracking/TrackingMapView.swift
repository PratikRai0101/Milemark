import MapKit
import SwiftUI

/// The live map during a run.
///
/// The map is the background and the recorded route is the content, so the
/// basemap is deliberately quiet: a muted standard style with no points of
/// interest and no traffic. The route and the runner are the only saturated
/// things on screen.
///
/// The map is an `MKMapView` rather than SwiftUI's `Map` because the muted
/// emphasis style is only available there, and the route is drawn by MapKit
/// itself so it keeps its full colour while the basemap is quiet.
struct TrackingMapView: UIViewRepresentable {
    let points: [RoutePoint]
    var breaks: [Int] = []
    let currentCoordinate: CLLocationCoordinate2D?
    let followsRunner: Bool
    /// The style the map is drawn in.
    var style: MapStyle = .milemark
    let onUserInteraction: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.preferredConfiguration = style.configuration()
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        mapView.setUserTrackingMode(.none, animated: false)
        context.coordinator.onUserInteraction = onUserInteraction
        context.coordinator.style = style
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.onUserInteraction = onUserInteraction
        context.coordinator.style = style

        // The style is applied as a whole, so the basemap and the route
        // always agree about what they are.
        if context.coordinator.appliedStyle != style {
            context.coordinator.appliedStyle = style
            mapView.preferredConfiguration = style.configuration()
        }

        // The route overlay is replaced rather than updated, so a long run
        // does not accumulate thousands of overlays.
        mapView.removeOverlays(mapView.overlays)
        context.coordinator.casingOverlays.removeAll()
        // One overlay per segment, so a pause is a gap in the track rather
        // than a straight line across it.
        for segment in RouteGeometry.segments(points, breaks: breaks) where segment.count > 1 {
            let coordinates = segment.map(\.coordinate)
            if style.drawsItsOwnRoute {
                // A casing under the line, the way a road is printed: a wide
                // dark stroke with the bright line laid over it, so the track
                // reads as inked on the map rather than floating above it.
                let casing = MKPolyline(coordinates: coordinates, count: coordinates.count)
                context.coordinator.casingOverlays.insert(ObjectIdentifier(casing))
                mapView.addOverlay(casing, level: .aboveRoads)

                // The bright line goes above the labels, so that a street
                // name never cuts through the track.
                let line = MKPolyline(coordinates: coordinates, count: coordinates.count)
                mapView.addOverlay(line, level: .aboveLabels)
            } else {
                let line = MKPolyline(coordinates: coordinates, count: coordinates.count)
                mapView.addOverlay(line, level: .aboveRoads)
            }
        }

        mapView.removeAnnotations(mapView.annotations)
        if let first = points.first {
            let start = MilemarkPointAnnotation(coordinate: first.coordinate, kind: .start)
            mapView.addAnnotation(start)
        }
        if let currentCoordinate {
            let here = MilemarkPointAnnotation(coordinate: currentCoordinate, kind: .runner)
            mapView.addAnnotation(here)
        }

        // The camera only moves when the runner has moved. Moving it on every
        // update would make each camera change trigger another one.
        if followsRunner,
           let currentCoordinate,
           context.coordinator.needsCameraMove(to: currentCoordinate) {
            context.coordinator.noteCamera(at: currentCoordinate)
            let camera = MKMapCamera(
                lookingAtCenter: currentCoordinate,
                fromDistance: 900,
                pitch: 0,
                heading: 0
            )
            mapView.setCamera(camera, animated: true)
        }
    }

    /// Watches for the runner panning the map so the app can stop following.
    final class Coordinator: NSObject, MKMapViewDelegate {
        var onUserInteraction: () -> Void = {}
        var style: MapStyle = .milemark
        /// The style currently applied to the map, so it is not reapplied on
        /// every update.
        var appliedStyle: MapStyle?
        /// The overlays that are the dark casing under the route.
        var casingOverlays: Set<ObjectIdentifier> = []
        private var cameraCoordinate: CLLocationCoordinate2D?

        func needsCameraMove(to coordinate: CLLocationCoordinate2D) -> Bool {
            guard let cameraCoordinate else { return true }
            return abs(cameraCoordinate.latitude - coordinate.latitude) > 0.000_005
                || abs(cameraCoordinate.longitude - coordinate.longitude) > 0.000_005
        }

        func noteCamera(at coordinate: CLLocationCoordinate2D) {
            cameraCoordinate = coordinate
        }

        func mapView(_ mapView: MKMapView, didMove gesture: UIGestureRecognizer) {
            onUserInteraction()
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolylineRenderer(polyline: polyline)
            let isCasing = casingOverlays.contains(ObjectIdentifier(overlay))

            if isCasing {
                // The casing is the ink under the line: a warm dark brown
                // rather than black, so it sits with the paper.
                renderer.strokeColor = UIColor(red: 0.38, green: 0.16, blue: 0.06, alpha: 0.85)
                renderer.lineWidth = 7.5
            } else {
                renderer.strokeColor = UIColor(red: 0.86, green: 0.35, blue: 0.13, alpha: 1)
                renderer.lineWidth = 4
            }
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let point = annotation as? MilemarkPointAnnotation else { return nil }
            let identifier = "milemark-\(point.kind.identifier)"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MilemarkAnnotationView)
                ?? MilemarkAnnotationView(kind: point.kind, annotation: annotation, reuseIdentifier: identifier)
            view.annotation = annotation
            return view
        }
    }
}

/// A point the app marks on the map.
final class MilemarkPointAnnotation: NSObject, MKAnnotation {
    enum Kind: String {
        case start
        case runner

        var identifier: String { rawValue }
    }

    let kind: Kind
    let coordinate: CLLocationCoordinate2D

    init(coordinate: CLLocationCoordinate2D, kind: Kind) {
        self.coordinate = coordinate
        self.kind = kind
        super.init()
    }

    var title: String? {
        switch kind {
        case .start: "Start"
        case .runner: "You"
        }
    }
}
