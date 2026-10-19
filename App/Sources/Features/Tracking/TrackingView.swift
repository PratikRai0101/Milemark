import CoreLocation
import MapKit
import SwiftUI

/// Live recording.
///
/// The map is the background; the recorded route is the content. The runner
/// sees distance and elapsed time, and can pause, resume or finish. Finishing
/// opens a review step before anything is printed, so a run is never committed
/// by accident.
struct TrackingView: View {
    @Environment(RunStore.self) private var store
    @Environment(RunRecorder.self) private var recorder
    @Environment(\.scenePhase) private var scenePhase

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var followsRunner = true
    @State private var isReviewing = false
    @State private var draftTitle = ""
    @State private var draftNote = ""
    @State private var tick = Date.now

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            map
            controls
        }
        .background(Theme.ground)
        .navigationTitle("Outdoor run")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.ground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { recorder.prepare() }
        .onReceive(ticker) { now in
            tick = now
            recorder.tick(now: now)
        }
        .onChange(of: scenePhase) { _, phase in
            // Recording must continue while the phone is locked or in a pocket.
            if phase == .background, recorder.phase == .recording {
                recorder.pause()
            }
        }
        .sheet(isPresented: $isReviewing) {
            ReviewSheet(
                title: $draftTitle,
                note: $draftNote,
                distanceKilometres: recorder.distanceMeters / 1000,
                elapsed: recorder.elapsedTime,
                pace: recorder.paceSecondsPerKm,
                onCancel: { isReviewing = false },
                onPrint: { title, note in
                    // The recording owns the route, so the printed receipt
                    // carries the geometry that was actually run.
                    let run = recorder.makeRun(
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Outdoor run" : title,
                        note: note.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    store.add(run)
                    isReviewing = false
                    recorder.reset()
                    return run
                }
            )
            .presentationDetents([.large])
        }
    }

    // MARK: - Map

    private var map: some View {
        Map(position: $cameraPosition) {
            MapPolyline(coordinates: recorder.points.map(\.coordinate))
                .stroke(Theme.signal, style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
            if let start = recorder.points.first {
                Annotation("", coordinate: start.coordinate) {
                    Circle()
                        .fill(.white)
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(Theme.signal, lineWidth: 2.5))
                }
            }
            if let current = recorder.currentCoordinate {
                Annotation("", coordinate: current) {
                    ZStack {
                        Circle().fill(Theme.signal.opacity(0.18)).frame(width: 22, height: 22)
                        Circle().fill(Theme.signal).frame(width: 11, height: 11)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .overlay(alignment: .topLeading) {
            Text(placeLabel)
                .font(Theme.Font.label)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.thinMaterial, in: Capsule())
                .padding(14)
        }
        .overlay(alignment: .topTrailing) {
            if !followsRunner {
                Button {
                    followsRunner = true
                    recentre()
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial, in: Circle())
                }
                .accessibilityLabel("Recentre map")
                .padding(14)
            }
        }
        .onMapCameraChange(frequency: .onEnd) { _ in
            followsRunner = false
        }
        .onChange(of: recorder.currentCoordinate?.latitude) { _, _ in
            guard followsRunner, let coordinate = recorder.currentCoordinate else { return }
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: coordinate,
                    distance: 900,
                    heading: 0,
                    pitch: 0
                )
            )
        }
        .frame(maxHeight: .infinity)
    }

    private var placeLabel: String {
        switch recorder.phase {
        case .idle, .ready: "Ready when you are"
        case .recording: "Recording"
        case .paused: "Paused"
        case .finished: "Finished"
        }
    }

    private func recentre() {
        guard let coordinate = recorder.currentCoordinate else { return }
        cameraPosition = .camera(MapCamera(centerCoordinate: coordinate, distance: 900, heading: 0, pitch: 0))
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Outdoor run")
                    .font(Theme.Font.label)
                    .foregroundStyle(Theme.secondary)
                Spacer()
                Text(statusLabel)
                    .font(Theme.Font.labelStrong)
                    .foregroundStyle(recorder.phase == .recording ? Theme.signal : Theme.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.2f", recorder.distanceMeters / 1000))
                    .font(Theme.Font.liveDistance)
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text("km")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.secondary)
            }

            HStack {
                metric(value: Format.duration(recorder.elapsedTime), label: "Elapsed time")
                Spacer()
                metric(value: Format.pace(recorder.paceSecondsPerKm), label: "Avg pace /km")
            }

            buttons

            Text(hintText)
                .font(Theme.Font.label)
                .foregroundStyle(Theme.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .background(Theme.ground)
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
            Text(label)
                .font(Theme.Font.label)
                .foregroundStyle(Theme.secondary)
        }
    }

    private var statusLabel: String {
        switch recorder.phase {
        case .idle: "READY"
        case .ready: "READY"
        case .recording: "RECORDING"
        case .paused: "PAUSED"
        case .finished: "COLLECTED"
        }
    }

    private var hintText: String {
        switch recorder.phase {
        case .idle, .ready: "Start when you are ready. The route records as you run."
        case .recording: "Recording. Pause if you stop."
        case .paused: "Paused. Resume, or finish and review."
        case .finished: "Run saved. Start another whenever you like."
        }
    }

    @ViewBuilder
    private var buttons: some View {
        HStack(spacing: 10) {
            switch recorder.phase {
            case .idle, .ready:
                Button {
                    recorder.start()
                } label: {
                    Label("Start run", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryActionStyle())

            case .recording:
                Button {
                    recorder.pause()
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
                .buttonStyle(PrimaryActionStyle())
                Button {
                    recorder.pause()
                    draftTitle = "Outdoor run"
                    draftNote = ""
                    isReviewing = true
                } label: {
                    Label("Finish", systemImage: "stop.fill")
                }
                .buttonStyle(SecondaryActionStyle())

            case .paused:
                Button {
                    recorder.resume()
                } label: {
                    Label("Resume", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryActionStyle())
                Button {
                    draftTitle = "Outdoor run"
                    draftNote = ""
                    isReviewing = true
                } label: {
                    Label("Finish", systemImage: "stop.fill")
                }
                .buttonStyle(SecondaryActionStyle())

            case .finished:
                Button {
                    recorder.reset()
                    recorder.prepare()
                } label: {
                    Label("Start another run", systemImage: "arrow.clockwise")
                }
                .buttonStyle(PrimaryActionStyle())
            }
        }
    }
}

// MARK: - Button styles

struct PrimaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.action)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Theme.ink, in: Capsule())
            .foregroundStyle(Theme.ground)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(duration: 0.22, bounce: 0), value: configuration.isPressed)
    }
}

struct SecondaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Font.action)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Theme.tile, in: Capsule())
            .foregroundStyle(Theme.ink)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(duration: 0.22, bounce: 0), value: configuration.isPressed)
    }
}
