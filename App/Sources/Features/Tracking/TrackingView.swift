import Combine
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

    @State private var followsRunner = true
    @State private var isReviewing = false
    @State private var draftTitle = ""
    @State private var draftNote = ""
    @State private var printedRun: Run?
    /// The live distance is the hero of the screen, so it scales with the
    /// reader's text size rather than staying fixed.
    @ScaledMetric(relativeTo: .largeTitle) private var liveDistanceSize: CGFloat = 56
    @State private var saveFailed = false

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
        .task {
            // -startRecording begins a run immediately, so screenshots and UI
            // checks can exercise the tracking screen without a tap.
            if ProcessInfo.processInfo.arguments.contains("-startRecording"),
               recorder.phase == .ready {
                recorder.start()
            }
        }
        .onReceive(ticker) { _ in
            recorder.tick()
        }
        .onChange(of: scenePhase) { _, phase in
            // Recording continues while the phone is locked or in a pocket:
            // the location manager keeps the track, and the clock is counted
            // by the recorder rather than by this view. Pausing here would
            // silently end a run the moment the screen went dark.
        }
        .navigationDestination(item: $printedRun) { run in
            ReceiptView(run: run)
        }
        .alert("The run could not be saved", isPresented: $saveFailed) {
            Button("Keep the recording") { }
            Button("Try again") { saveFailed = false }
        } message: {
            Text(store.lastError ?? "The runs file could not be written. The recording has been kept so you can try again.")
        }
        .task {
            // -openReview shows the review step on its own, so a screenshot
            // or a UI check can be taken of it without recording a run first.
            if ProcessInfo.processInfo.arguments.contains("-openReview") {
                draftTitle = "Outdoor run"
                draftNote = "Six reps around the block. Legs gone by the fourth."
                isReviewing = true
            }
        }
        .sheet(isPresented: $isReviewing) {
            ReviewSheet(
                title: $draftTitle,
                note: $draftNote,
                distanceKilometres: recorder.distanceMeters / 1000,
                elapsed: recorder.elapsedTime(),
                pace: recorder.paceSecondsPerKm,
                onCancel: { isReviewing = false },
                onPrint: { title, note in
                    // The recording owns the route, so the printed receipt
                    // carries the geometry that was actually run.
                    let run = recorder.makeRun(
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Outdoor run" : title,
                        note: note.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    // The run is only cleared once it has reached the disk,
                    // so a failed write does not lose it.
                    if store.add(run) {
                        isReviewing = false
                        printedRun = run
                        recorder.reset()
                    } else {
                        saveFailed = true
                    }
                    return run
                }
            )
            .presentationDetents([.large])
        }
    }

    // MARK: - Map

    private var map: some View {
        TrackingMapView(
            points: recorder.points,
            breaks: recorder.segmentBreaks,
            currentCoordinate: recorder.currentCoordinate,
            followsRunner: followsRunner,
            onUserInteraction: { followsRunner = false }
        )
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
                } label: {
                    Image(systemName: "location.fill")
                        .font(Theme.Font.body)
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial, in: Circle())
                }
                .accessibilityLabel("Recentre map")
                .padding(14)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var placeLabel: String {
        switch recorder.phase {
        case .idle, .ready:
            switch recorder.locationStatus {
            case .denied: "Location is off"
            case .restricted: "Location is restricted"
            case .searching: "Finding your position"
            default: "Ready when you are"
            }
        case .recording: "Recording"
        case .paused: "Paused"
        case .finished: "Finished"
        }
    }

    /// Whether the runner can actually record.
    ///
    /// A run cannot be recorded without location access, so the app says so
    /// rather than pretending to record a route it cannot see.
    private var canRecord: Bool {
        recorder.locationStatus != .denied && recorder.locationStatus != .restricted
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
                    .font(.system(size: liveDistanceSize, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text("km")
                    .font(Theme.Font.value)
                    .foregroundStyle(Theme.secondary)
            }

            // The two figures sit side by side when there is room. When there
            // is not, they become a column rather than squeezing their own
            // labels into an ellipsis.
            ViewThatFits(in: .horizontal) {
                HStack {
                    metric(value: Format.duration(recorder.elapsedTime()), label: "Elapsed time")
                    Spacer()
                    metric(value: Format.pace(recorder.paceSecondsPerKm), label: "Avg pace /km")
                }
                VStack(alignment: .leading, spacing: 10) {
                    metric(value: Format.duration(recorder.elapsedTime()), label: "Elapsed time")
                    metric(value: Format.pace(recorder.paceSecondsPerKm), label: "Avg pace /km")
                }
            }

            buttons

            Text(hintText)
                .font(Theme.Font.label)
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .background(Theme.ground)
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(Theme.Font.value)
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
        case .paused: recorder.isAutoPaused ? "AUTO-PAUSED" : "PAUSED"
        case .finished: "COLLECTED"
        }
    }

    private var hintText: String {
        switch recorder.phase {
        case .idle, .ready:
            switch recorder.locationStatus {
            case .denied:
                "Milemark needs location access to record a route. Turn it on in Settings."
            case .restricted:
                "Location is restricted on this device, so a route cannot be recorded."
            case .searching:
                "Finding your position. The route starts when the first fix arrives."
            default:
                "Start when you are ready. The route records as you run."
            }
        case .recording: "Recording. Pause if you stop."
        case .paused:
            recorder.isAutoPaused
                ? "Paused because you stopped. Resume when you start again."
                : "Paused. Resume, or finish and review."
        case .finished: "Run saved. Start another whenever you like."
        }
    }

    @ViewBuilder
    private var buttons: some View {
        HStack(spacing: 10) {
            switch recorder.phase {
            case .idle, .ready:
                if canRecord {
                    Button {
                        recorder.start()
                    } label: {
                        Label("Start run", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryActionStyle())
                } else {
                    // A route cannot be recorded without location access, so
                    // the app says so instead of pretending to record.
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open Settings", systemImage: "gear")
                    }
                    .buttonStyle(PrimaryActionStyle())
                }

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
            .frame(minHeight: 52)
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
            .frame(minHeight: 52)
            .background(Theme.tile, in: Capsule())
            .foregroundStyle(Theme.ink)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(duration: 0.22, bounce: 0), value: configuration.isPressed)
    }
}
