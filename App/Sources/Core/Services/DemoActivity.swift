import Foundation

/// Sample activities for people who want to see a receipt before recording a
/// run of their own.
///
/// The routes follow **real mapped streets** from the OpenStreetMap data
/// bundled in `design/assets`. Each one is a genuine closed loop in that
/// network — the streets a runner would actually take around a block or a
/// park — so a sample route is a real shape rather than an invented line.
///
/// They are **not** recordings of anyone's actual run, and the archive header
/// says the data is demo data.
public enum DemoActivity {
    /// A run built from a named loop.
    private struct Recipe {
        var title: String
        var note: String = ""
        var daysAgo: Int
        /// Index into `DemoRoute.loops`.
        var loopIndex: Int
        /// Target distance in kilometres. The loop is repeated as needed.
        var distanceKilometres: Double
        /// Average pace in seconds per kilometre.
        var paceSecondsPerKm: Double
        var elevationGain: Double
        var heartRate: Int?
    }

    private static let recipes: [Recipe] = [
        Recipe(
            title: "Interval",
            note: "Six reps around the block. Legs gone by the fourth.",
            daysAgo: 1,
            loopIndex: 0,
            distanceKilometres: 9.4,
            paceSecondsPerKm: 312,
            elevationGain: 101,
            heartRate: 160
        ),
        Recipe(
            title: "Riverside easy",
            daysAgo: 3,
            loopIndex: 4,
            distanceKilometres: 6.4,
            paceSecondsPerKm: 348,
            elevationGain: 26,
            heartRate: 146
        ),
        Recipe(
            title: "Track repeats",
            daysAgo: 5,
            loopIndex: 8,
            distanceKilometres: 7.0,
            paceSecondsPerKm: 337,
            elevationGain: 12,
            heartRate: 157
        ),
        Recipe(
            title: "Recovery",
            daysAgo: 7,
            loopIndex: 2,
            distanceKilometres: 4.9,
            paceSecondsPerKm: 384,
            elevationGain: 18,
            heartRate: 133
        ),
        Recipe(
            title: "Canal loop",
            daysAgo: 9,
            loopIndex: 5,
            distanceKilometres: 6.0,
            paceSecondsPerKm: 341,
            elevationGain: 24,
            heartRate: 148
        ),
        Recipe(
            title: "Long run",
            note: "Slow and steady. Watched the sun come up over the basin.",
            daysAgo: 11,
            loopIndex: 7,
            distanceKilometres: 12.0,
            paceSecondsPerKm: 373,
            elevationGain: 48,
            heartRate: 151
        ),
        Recipe(
            title: "Hill repeats",
            daysAgo: 13,
            loopIndex: 6,
            distanceKilometres: 5.1,
            paceSecondsPerKm: 375,
            elevationGain: 96,
            heartRate: 162
        ),
        Recipe(
            title: "Park loop",
            daysAgo: 15,
            loopIndex: 1,
            distanceKilometres: 6.5,
            paceSecondsPerKm: 353,
            elevationGain: 31,
            heartRate: 145
        ),
        Recipe(
            title: "Lunch run",
            daysAgo: 17,
            loopIndex: 3,
            distanceKilometres: 3.0,
            paceSecondsPerKm: 368,
            elevationGain: 14,
            heartRate: 140
        )
    ]

    /// Builds the sample activities, newest first.
    public static func all() -> [Run] {
        recipes.compactMap(makeRun)
    }

    /// Builds one run from a recipe.
    ///
    /// Time is derived from distance and pace, so the three numbers on the
    /// receipt always agree with each other: the pace chart, the elapsed time
    /// and the distance are the same run, not three separate fixtures.
    private static func makeRun(_ recipe: Recipe) -> Run? {
        guard recipe.loopIndex < DemoRoute.loops.count else { return nil }
        let loop = DemoRoute.loops[recipe.loopIndex]
        guard loop.count > 1 else { return nil }

        let targetMetres = recipe.distanceKilometres * 1000

        var points: [RoutePoint] = []
        var timestamp = Date().addingTimeInterval(-TimeInterval(recipe.daysAgo) * 86_400)
        var covered = 0.0
        var lap = 0

        while covered < targetMetres, lap < 40 {
            var previous: (latitude: Double, longitude: Double)?
            for coordinate in loop {
                defer { previous = (coordinate.latitude, coordinate.longitude) }
                guard let previous else { continue }

                let step = RouteGeometry.distance(
                    from: previous.latitude,
                    longitude1: previous.longitude,
                    to: coordinate.latitude,
                    longitude2: coordinate.longitude
                )
                guard step > 0 else { continue }
                covered += step
                guard covered <= targetMetres else { break }

                // A gentle surge in the middle third of the run, so the pace
                // chart shows something real.
                let progress = covered / targetMetres
                let paceFactor = 1.0 - 0.13 * exp(-pow((progress - 0.55) / 0.17, 2))
                let pace = recipe.paceSecondsPerKm * paceFactor
                // Convert to the time this step took: pace is per kilometre.
                timestamp = timestamp.addingTimeInterval(step / 1000 * pace)

                points.append(
                    RoutePoint(
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude,
                        altitude: 0,
                        timestamp: timestamp,
                        horizontalAccuracy: 5,
                        speed: 1000 / pace
                    )
                )
            }
            lap += 1
        }

        guard points.count > 1 else { return nil }

        let distance = RouteGeometry.totalDistance(points)
        let movingTime = points.last?.timestamp.timeIntervalSince(points.first?.timestamp ?? timestamp) ?? 0

        return Run(
            title: recipe.title,
            note: recipe.note,
            startedAt: points[0].timestamp,
            endedAt: points.last?.timestamp ?? timestamp,
            elapsedTime: movingTime,
            movingTime: movingTime,
            distanceMeters: distance,
            elevationGainMeters: recipe.elevationGain,
            averageHeartRate: recipe.heartRate,
            points: points,
            isCollected: false,
            source: .imported
        )
    }
}
