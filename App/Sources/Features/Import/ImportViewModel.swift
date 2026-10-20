import Foundation
import Observation
import SwiftUI

/// One run that could be imported, and whether it is already in the archive.
struct ImportCandidate: Identifiable, Equatable {
    var run: Run
    var isAlreadyImported: Bool

    var id: UUID { run.id }
}

/// Drives an import from one service.
///
/// The screen and the network are kept apart so that the screen has one job:
/// show what is on offer, and hand back what was chosen.
@MainActor
@Observable
final class ImportViewModel {
    enum Source: String, Identifiable, Hashable {
        case strava
        case health

        var id: String { rawValue }
        var title: String {
            switch self {
            case .strava: "Strava"
            case .health: "Health"
            }
        }
    }

    private(set) var candidates: [ImportCandidate] = []
    private(set) var isLoading = false
    private(set) var message: String?

    private let source: Source
    private let store: RunStore
    private let strava: StravaService
    private let health: HealthKitService

    init(
        source: Source,
        store: RunStore,
        strava: StravaService,
        health: HealthKitService
    ) {
        self.source = source
        self.store = store
        self.strava = strava
        self.health = health
    }

    /// Whether this source can be used at all in this build.
    var isAvailable: Bool {
        switch source {
        case .strava: strava.state != .notConfigured
        case .health: health.state != .unavailable
        }
    }

    /// Why the source cannot be used, when it cannot.
    var unavailableReason: String? {
        switch source {
        case .strava:
            if strava.state == .notConfigured {
                return "This build has no Strava keys. Add STRAVA_CLIENT_ID and STRAVA_CLIENT_SECRET to the project's build settings to use it."
            }
            return nil
        case .health:
            if health.state == .unavailable {
                return "This device does not keep health data."
            }
            return nil
        }
    }

    /// The message to show when nothing can be imported.
    var emptyReason: String {
        switch source {
        case .strava:
            return "There are no Strava runs to bring in."
        case .health:
            // HealthKit does not say whether permission was refused, so an
            // empty list has two possible causes and the copy names both.
            return "There are no runs in Health to bring in. If you have workouts in the Health app, check that Milemark is allowed to read them under Settings → Health."
        }
    }

    /// Loads what the source has to offer.
    func load() async {
        isLoading = true
        message = nil
        defer { isLoading = false }

        do {
            let runs: [Run]
            switch source {
            case .strava:
                let stravaActivities = try await strava.activities()
                runs = stravaActivities.map { StravaRunMapper.makeRun(from: $0) }
            case .health:
                let healthRuns = try await health.recentRuns()
                runs = healthRuns.map(\.run)
            }
            candidates = runs.map { run in
                let sourceID = run.sourceID ?? ""
                return ImportCandidate(
                    run: run,
                    isAlreadyImported: !sourceID.isEmpty && store.hasImported(source: run.source, sourceID: sourceID)
                )
            }
        } catch {
            candidates = []
            message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Brings the chosen runs into the archive.
    @discardableResult
    func importRuns(_ chosen: [Run]) -> Bool {
        let result = store.importRuns(chosen)
        if !result.saved {
            message = "The runs could not be saved. The archive was left as it was."
            return false
        }
        message = result.added == 1
            ? "One run was brought in."
            : "\(result.added) runs were brought in."
        // The list is reloaded so that the runs just brought in are marked as
        // already here.
        candidates = candidates.map { candidate in
            var updated = candidate
            if let sourceID = candidate.run.sourceID {
                updated.isAlreadyImported = store.hasImported(source: candidate.run.source, sourceID: sourceID)
            }
            return updated
        }
        return true
    }
}
