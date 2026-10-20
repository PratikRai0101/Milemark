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
    let onUserInteraction: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        let configuration = MKStandardMapConfiguration(
            elevationStyle: .flat,
            emphasisStyle: .muted
        )
        configuration.showsTraffic = false
        configuration.pointOfInterestFilter = .excludingAll
        mapView.preferredConfiguration = configuration
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        mapView.setUserTrackingMode(.none, animated: false)
        context.coordinator.onUserInteraction = onUserInteraction
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.onUserInteraction = onUserInteraction

        // The route overlay is replaced rather than updated, so a long run
        // does not accumulate thousands of overlays.
        mapView.removeOverlays(mapView.overlays)
        // One overlay per segment, so a pause is a gap in the track rather
        // than a straight line across it.
        for segment in RouteGeometry.segments(points, breaks: breaks) where segment.count > 1 {
            let coordinates = segment.map(\.coordinate)
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline, level: .aboveRoads)
        }

        mapView.removeAnnotations(mapView.annotations)
        if let first = points.first {
            let start = MKPointAnnotation()
            start.coordinate = first.coordinate
            start.title = "Start"
            mapView.addAnnotation(start)
        }
        if let currentCoordinate {
            let here = MKPointAnnotation()
            here.coordinate = currentCoordinate
            here.title = "You"
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
            renderer.strokeColor = UIColor(red: 0.77, green: 0.32, blue: 0.12, alpha: 1)
            renderer.lineWidth = 4.5
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "milemark-runner"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.annotation = annotation

            if annotation.title == "Start" {
                view.markerTintColor = .white
                view.glyphImage = nil
            } else {
                view.markerTintColor = UIColor(red: 0.77, green: 0.32, blue: 0.12, alpha: 1)
                view.glyphImage = UIImage(systemName: "figure.run")
            }
            // The markers are for the eye, not for reading: no label sits
            // beside them.
            view.canShowCallout = false
            view.titleVisibility = .hidden
            view.subtitleVisibility = .hidden
            return view
        }
    }
}
