import CoreLocation
import Foundation
import Observation

/// Records location fixes for a run.
///
/// The recorder is deliberately conservative: it rejects stale and imprecise
/// samples, refuses implausible jumps, and does not add distance while the
/// runner is standing still. Pausing stops the clock and the distance, and
/// resuming does not draw a false line across the gap.
@MainActor
@Observable
public final class RunRecorder: NSObject {
    public enum Phase: Equatable {
        case idle
        case ready
        case recording
        case paused
        case finished
    }

    public enum LocationStatus: Equatable {
        case unknown
        case denied
        case restricted
        case searching
        case weak
        case good
    }

    // MARK: - Observable state

    public private(set) var phase: Phase = .idle
    public private(set) var points: [RoutePoint] = []
    public private(set) var segmentBreaks: [Int] = []
    public private(set) var distanceMeters: Double = 0
    public private(set) var elevationGainMeters: Double = 0
    public private(set) var currentCoordinate: CLLocationCoordinate2D?
    public private(set) var currentSpeedMetersPerSecond: Double = 0
    public private(set) var locationStatus: LocationStatus = .unknown
    public private(set) var startedAt: Date?
    public private(set) var lastError: String?
    /// Whether the recorder paused itself because the runner stopped moving.
    public private(set) var isAutoPaused = false

    // MARK: - Timing

    /// The time the recorder last read its clock.
    ///
    /// It is what the elapsed time is measured against, and it is what makes
    /// the screen update.
    public private(set) var now: Date = Date()

    /// The clock the recorder reads.
    ///
    /// It is injected so the timing can be tested without waiting for real
    /// seconds to pass.
    var clock: () -> Date = { Date() }

    /// The wall-clock time of the run, not counting time spent paused.
    ///
    /// It is worked out from the dates rather than from a timer, so it keeps
    /// counting when the phone is locked and the app is suspended.
    public func elapsedTime() -> TimeInterval {
        guard let startedAt else { return 0 }
        let moment = clock()
        let paused = accumulatedPause + (pausedAt.map { moment.timeIntervalSince($0) } ?? 0)
        return max(0, moment.timeIntervalSince(startedAt) - paused)
    }

    /// The time the route actually covers.
    ///
    /// It is the span between the recorded samples, so the time spent paused
    /// is not counted: no samples arrive while the run is paused.
    public private(set) var movingTime: TimeInterval = 0

    // MARK: - Dependencies

    private let manager = CLLocationManager()
    private var lastAccepted: RoutePoint?
    private var lastResumedAt: Date?
    /// Set when the run is paused, so the paused stretch can be taken out.
    private var pausedAt: Date?
    /// The total time spent paused so far.
    private var accumulatedPause: TimeInterval = 0
    /// Set when the first sample after a resume is expected, so the break is
    /// recorded on the route.
    private var awaitingSegmentBreak = false
    private var altitudeBaseline: Double?
    /// When the runner last moved far enough to count as running.
    private var lastMovementAt: Date?

    // MARK: - Init

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
    }

    // MARK: - Permissions

    public var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    public func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    public func requestBackgroundAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    // MARK: - Session control

    public func prepare() {
        guard phase == .idle else { return }
        phase = .ready
        refreshStatus()
        // The app asks for location when the recording screen is opened. Without
        // this the first run records nothing, because a manager that was never
        // authorised never delivers a fix.
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
    }

    public func start() {
        guard phase == .ready || phase == .paused else { return }
        let now = clock()
        if phase == .ready {
            startedAt = now
            points.removeAll()
            segmentBreaks.removeAll()
            distanceMeters = 0
            movingTime = 0
            elevationGainMeters = 0
            altitudeBaseline = nil
            accumulatedPause = 0
            pausedAt = nil
        } else {
            // Resuming must not connect the pause to the new position. The next
            // accepted fix starts a new segment, and no distance is counted
            // between the two sides of the gap.
            if let pausedAt {
                accumulatedPause += now.timeIntervalSince(pausedAt)
            }
            pausedAt = nil
            lastResumedAt = now
            lastAccepted = nil
            // The break is recorded when the first sample after the pause
            // arrives, so the route shows the gap rather than joining it.
            awaitingSegmentBreak = true
        }
        isAutoPaused = false
        lastMovementAt = nil
        phase = .recording
        manager.startUpdatingLocation()
    }

    /// Pauses the run.
    ///
    /// The clock is passed in so a pause always agrees with the rest of the
    /// session's timing.
    public func pause(now: Date? = nil) {
        guard phase == .recording else { return }
        pausedAt = now ?? clock()
        phase = .paused
        isAutoPaused = false
    }

    public func resume() {
        guard phase == .paused else { return }
        start()
    }

    public func reset() {
        manager.stopUpdatingLocation()
        phase = .idle
        points.removeAll()
        segmentBreaks.removeAll()
        movingTime = 0
        distanceMeters = 0
        elevationGainMeters = 0
        currentCoordinate = nil
        currentSpeedMetersPerSecond = 0
        startedAt = nil
        lastAccepted = nil
        lastResumedAt = nil
        pausedAt = nil
        accumulatedPause = 0
        awaitingSegmentBreak = false
        altitudeBaseline = nil
        lastError = nil
        isAutoPaused = false
        lastMovementAt = nil
    }

    /// Called by the tracking view's timer.
    ///
    /// The clock itself is worked out from the dates, so this only has to
    /// notice when the runner has stopped.
    public func tick() {
        now = clock()
        guard phase == .recording else { return }
        checkForAutoPause(now: now)
    }

    // MARK: - Metric helpers

    public var paceSecondsPerKm: Double? {
        RouteGeometry.paceSecondsPerKm(distanceMeters: distanceMeters, movingTime: movingTime)
    }

    public var averageSpeedMetersPerSecond: Double {
        guard movingTime > 0 else { return 0 }
        return distanceMeters / movingTime
    }

    // MARK: - Sample handling

    /// Absorbs a batch of location samples.
    func ingest(_ locations: [CLLocation]) {
        for location in locations {
            ingest([RoutePoint(location: location)])
        }
    }

    /// Absorbs a batch of samples.
    ///
    /// Internal rather than private so the recorder's decisions can be tested
    /// directly, without a live location feed.
    func ingest(_ samples: [RoutePoint]) {
        for point in samples {
            currentCoordinate = point.coordinate
            currentSpeedMetersPerSecond = point.speed

            guard phase == .recording else { continue }
            // A sample is judged against the clock, not against the last
            // tick: while the app is suspended no tick arrives, and a good
            // fix would be thrown away as stale.
            guard RouteGeometry.isAcceptable(point, now: clock()) else {
                if point.horizontalAccuracy < 0 {
                    locationStatus = .weak
                }
                continue
            }

            locationStatus = point.horizontalAccuracy <= 15 ? .good : .weak

            if let previous = lastAccepted {
                let delta = point.timestamp.timeIntervalSince(previous.timestamp)
                let step = RouteGeometry.distance(
                    from: previous.latitude,
                    longitude1: previous.longitude,
                    to: point.latitude,
                    longitude2: point.longitude
                )

                // A sample that arrives out of order cannot extend the route.
                guard delta > 0 else { continue }
                // Reject jumps that would mean running at an impossible speed.
                let impliedSpeed = step / delta
                if impliedSpeed > 12.0 { continue }
                // Standing still produces noise, not distance.
                guard step > 0.4 else { continue }

                // The first accepted sample after a resume starts a new
                // segment. The distance covered while the run was paused is
                // neither counted nor drawn.
                if let resumedAt = lastResumedAt, previous.timestamp < resumedAt {
                    lastResumedAt = nil
                    lastAccepted = point
                    segmentBreaks.append(points.count)
                    points.append(point)
                    continue
                }

                distanceMeters += step
                // The time the route covers. No samples arrive while the run
                // is paused, so the pause is not counted.
                movingTime += point.timestamp.timeIntervalSince(previous.timestamp)
                if step > 5 {
                    lastMovementAt = point.timestamp
                }
                if let baseline = altitudeBaseline {
                    let deltaAltitude = point.altitude - baseline
                    if deltaAltitude > 1 { elevationGainMeters += deltaAltitude }
                } else {
                    altitudeBaseline = point.altitude
                }
                altitudeBaseline = point.altitude
            } else {
                altitudeBaseline = point.altitude
                if awaitingSegmentBreak {
                    // The first sample of a new segment: record the break so
                    // the route shows the gap instead of joining it.
                    awaitingSegmentBreak = false
                    if !points.isEmpty {
                        segmentBreaks.append(points.count)
                    }
                }
            }

            lastAccepted = point
            points.append(point)
        }
    }

    /// Pauses the run when the runner has stopped moving.
    ///
    /// A runner who stops at a crossing should not have to reach for the
    /// phone. The test is deliberately slow: the runner has to stay still
    /// for a while, and the run has to have covered some ground first, so
    /// a brief pause at traffic lights is not mistaken for a stop.
    private func checkForAutoPause(now: Date = .now) {
        guard phase == .recording, !isAutoPaused else { return }
        guard distanceMeters > 20 else { return }
        guard let lastMovementAt else {
            self.lastMovementAt = now
            return
        }
        let stillFor = now.timeIntervalSince(lastMovementAt)
        guard stillFor > 12 else { return }
        // A sample that says the runner is still moving cancels the pause.
        guard currentSpeedMetersPerSecond < 1.0 else {
            self.lastMovementAt = now
            return
        }
        // The clock is not ticked here: the tick that led to this check has
        // already been counted, and ticking again would call straight back
        // into this method.
        //
        // An automatic pause is a real pause, so the clock stops with it.
        pausedAt = now
        phase = .paused
        isAutoPaused = true
    }

    private func refreshStatus() {
        switch manager.authorizationStatus {
        case .denied:
            locationStatus = .denied
        case .restricted:
            locationStatus = .restricted
        case .notDetermined:
            locationStatus = .unknown
        default:
            locationStatus = .searching
        }
    }

    // MARK: - Result

    /// Builds the run from the recorded session.
    public func makeRun(title: String, note: String) -> Run {
        Run(
            title: title,
            note: note,
            startedAt: startedAt ?? .now,
            endedAt: .now,
            elapsedTime: elapsedTime(),
            movingTime: movingTime,
            distanceMeters: distanceMeters,
            elevationGainMeters: elevationGainMeters,
            points: points,
            segmentBreaks: segmentBreaks,
            isCollected: false,
            source: .recorded
        )
    }
}

// MARK: - CLLocationManagerDelegate

extension RunRecorder: CLLocationManagerDelegate {
    public nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            self?.refreshStatus()
            // The manager only starts delivering fixes once it is allowed to.
            if self?.manager.authorizationStatus == .authorizedWhenInUse
                || self?.manager.authorizationStatus == .authorizedAlways {
                self?.manager.startUpdatingLocation()
            }
        }
    }

    public nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor [weak self] in
            self?.ingest(locations)
        }
    }

    public nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.lastError = error.localizedDescription
        }
    }
}
