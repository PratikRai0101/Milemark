// Extracts the demo route geometry from the bundled OpenStreetMap extract.
//
// The sample activities should follow real mapped paths, not invented
// coordinates. This reads the same Overpass extract the map background was
// drawn from, builds a graph of the real footways, cycleways and streets, and
// finds genuine loops to run around.
//
// A loop is a closed walk in the graph: the streets a runner would actually
// take around a block or a park, rather than a line drawn twice.
//
// Run: swift design/make-demo-routes.swift <kallang-map.json> <output.swift>
import Foundation

struct Point: Hashable {
    var lat: Double
    var lon: Double

    /// Rounded key for graph nodes. Six decimal places is about 10 cm.
    var key: String { "\(Int((lat * 1_000_000).rounded())):\(Int((lon * 1_000_000).rounded()))" }
}

struct Way {
    var name: String
    var highway: String
    var geometry: [Point]
}

func metres(_ a: Point, _ b: Point) -> Double {
    let earthRadius = 6_378_137.0
    let dLat = (b.lat - a.lat) * .pi / 180
    let dLon = (b.lon - a.lon) * .pi / 180
    let lat1 = a.lat * .pi / 180
    let lat2 = b.lat * .pi / 180
    let h = sin(dLat / 2) * sin(dLat / 2)
        + sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2)
    return earthRadius * 2 * atan2(sqrt(h), sqrt(1 - h))
}

/// Unzips the gzip-compressed extract that the map asset ships with.
func loadExtract(from jsonPath: String) throws -> [[String: Any]] {
    let data = try Data(contentsOf: URL(fileURLWithPath: jsonPath))
    let object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    let source = object["sourceExtract"] as! [String: Any]
    let encoded = source["data"] as! String
    let compressed = Data(base64Encoded: encoded)!

    // The gzip container is decompressed with the system tool, which is
    // always present and keeps this script free of a compression dependency.
    let temporary = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "milemark-extract-\(UUID().uuidString).gz")
    try compressed.write(to: temporary)
    defer { try? FileManager.default.removeItem(at: temporary) }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/gzip")
    process.arguments = ["-dc", temporary.path]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    try process.run()
    let decompressed = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    let extract = try JSONSerialization.jsonObject(with: decompressed) as! [String: Any]
    return extract["elements"] as! [[String: Any]]
}

let arguments = CommandLine.arguments
guard arguments.count > 2 else {
    fatalError("Usage: make-demo-routes <kallang-map.json> <output.swift>")
}

let elements = try loadExtract(from: arguments[1])

// Highways a runner would actually use.
let runnable = Set([
    "footway", "cycleway", "path", "track", "living_street", "pedestrian",
    "residential", "unclassified", "service", "tertiary", "secondary", "primary"
])
// Ways that a runner would avoid or that break a loop.
let excluded = Set(["steps", "motorway", "motorway_link", "trunk", "trunk_link", "construction"])

var ways: [Way] = []
for element in elements {
    guard element["type"] as? String == "way" else { continue }
    let tags = element["tags"] as? [String: Any] ?? [:]
    let highway = tags["highway"] as? String ?? ""
    guard runnable.contains(highway), !excluded.contains(highway) else { continue }
    guard let geometry = element["geometry"] as? [[String: Any]], geometry.count > 1 else { continue }
    let points = geometry.compactMap { dictionary -> Point? in
        guard let lat = dictionary["lat"] as? Double, let lon = dictionary["lon"] as? Double else { return nil }
        return Point(lat: lat, lon: lon)
    }
    guard points.count > 1 else { continue }
    ways.append(Way(name: tags["name"] as? String ?? "", highway: highway, geometry: points))
}

// MARK: - Graph

var nodes: [String: Point] = [:]
var adjacency: [String: [String]] = [:]

for way in ways {
    var previousKey: String?
    for point in way.geometry {
        let key = point.key
        nodes[key] = point
        if let previousKey, previousKey != key {
            adjacency[previousKey, default: []].append(key)
            adjacency[key, default: []].append(previousKey)
        }
        previousKey = key
    }
}

// Remove dead ends so a loop is not cut short by a stub.
var pruned = true
while pruned {
    pruned = false
    let dead = adjacency.filter { $0.value.count < 2 }.map(\.key)
    guard !dead.isEmpty else { break }
    for key in dead {
        adjacency.removeValue(forKey: key)
        for neighbour in adjacency.keys {
            adjacency[neighbour]?.removeAll { $0 == key }
        }
        pruned = true
    }
}

// MARK: - Loop search

/// Searches for a closed walk that starts and ends at the same node.
///
/// The search prefers continuing in the same direction, which is how a runner
/// actually moves through a street grid, and it rewards loops that enclose
/// real space rather than doubling back on themselves.
func findLoop(start: String, maximumEdges: Int) -> [String]? {
    var best: [String]?
    var bestScore = -Double.greatestFiniteMagnitude
    var explored = 0
    let explorationLimit = 60_000

    /// Enclosed area in square metres, measured on a local flat plane.
    func area(of path: [String]) -> Double {
        guard path.count > 2 else { return 0 }
        let origin = nodes[path[0]]!
        let metresPerDegreeLatitude = 110_574.0
        let metresPerDegreeLongitude = 111_320.0 * cos(origin.lat * .pi / 180)
        var total = 0.0
        for index in path.indices.dropLast() {
            let a = nodes[path[index]]!
            let b = nodes[path[index + 1]]!
            let ax = (a.lon - origin.lon) * metresPerDegreeLongitude
            let ay = (a.lat - origin.lat) * metresPerDegreeLatitude
            let bx = (b.lon - origin.lon) * metresPerDegreeLongitude
            let by = (b.lat - origin.lat) * metresPerDegreeLatitude
            total += ax * by - bx * ay
        }
        return abs(total) / 2
    }

    func length(of path: [String]) -> Double {
        var total = 0.0
        for index in path.indices.dropLast() {
            total += metres(nodes[path[index]]!, nodes[path[index + 1]]!)
        }
        return total
    }

    func score(of path: [String]) -> Double {
        let enclosed = area(of: path)
        let distance = length(of: path)
        // A usable loop is worth running: a few hundred metres and a few
        // thousand metres, enclosing real ground.
        guard distance > 400, distance < 3200 else { return -1 }
        guard enclosed > 12_000 else { return -1 }
        // A loop that doubles back on itself has almost no enclosed area, and
        // one that is far longer than it is wide prints as a line.
        guard narrowestSide(of: path) > 120 else { return -1 }
        guard squareness(of: path) > 0.55 else { return -1 }
        return enclosed - abs(distance - 1400) * 12
    }

    /// The shortest side of the loop's bounding box, in metres.
    ///
    /// A loop that is much longer than it is wide prints as a line, so the
    /// shape has to have body in both directions.
    func narrowestSide(of path: [String]) -> Double {
        var minLatitude = Double.greatestFiniteMagnitude
        var maxLatitude = -Double.greatestFiniteMagnitude
        var minLongitude = Double.greatestFiniteMagnitude
        var maxLongitude = -Double.greatestFiniteMagnitude
        for key in path {
            guard let point = nodes[key] else { continue }
            minLatitude = min(minLatitude, point.lat)
            maxLatitude = max(maxLatitude, point.lat)
            minLongitude = min(minLongitude, point.lon)
            maxLongitude = max(maxLongitude, point.lon)
        }
        let height = (maxLatitude - minLatitude) * 110_574
        let width = (maxLongitude - minLongitude) * 111_320 * cos(minLatitude * .pi / 180)
        return min(width, height)
    }

    /// How close the loop is to being square. A long thin corridor prints as
    /// a line however well it is drawn.
    func squareness(of path: [String]) -> Double {
        var minLatitude = Double.greatestFiniteMagnitude
        var maxLatitude = -Double.greatestFiniteMagnitude
        var minLongitude = Double.greatestFiniteMagnitude
        var maxLongitude = -Double.greatestFiniteMagnitude
        for key in path {
            guard let point = nodes[key] else { continue }
            minLatitude = min(minLatitude, point.lat)
            maxLatitude = max(maxLatitude, point.lat)
            minLongitude = min(minLongitude, point.lon)
            maxLongitude = max(maxLongitude, point.lon)
        }
        let height = max((maxLatitude - minLatitude) * 110_574, 1)
        let width = max((maxLongitude - minLongitude) * 111_320 * cos(minLatitude * .pi / 180), 1)
        return min(width, height) / max(width, height)
    }

    func search(path: [String], visited: Set<String>) {
        explored += 1
        if explored > explorationLimit { return }
        guard path.count <= maximumEdges else { return }
        let current = path[path.count - 1]
        let previous = path.count > 1 ? path[path.count - 2] : nil

        // Closing the loop.
        if path.count >= 8, adjacency[current]?.contains(path[0]) == true {
            let candidate = path + [path[0]]
            let value = score(of: candidate)
            if value > bestScore {
                bestScore = value
                best = candidate
            }
            return
        }

        for next in adjacency[current] ?? [] {
            if next == previous { continue }
            if visited.contains(next) { continue }
            search(path: path + [next], visited: visited.union([next]))
        }
    }

    search(path: [start], visited: [start])
    return best
}

/// Tries every node as a starting point and keeps the best loops found.
var loops: [(points: [Point], length: Double)] = []

// Search from many starting points. A node deep inside a small block can only
// close a small loop, so every node is tried and the best results are kept.
for (index, start) in adjacency.keys.shuffled().enumerated() {
    guard let loop = findLoop(start: start, maximumEdges: 22) else { continue }
    let points = loop.compactMap { nodes[$0] }
    guard points.count >= 8 else { continue }
    var length = 0.0
    for index in points.indices.dropLast() {
        length += metres(points[index], points[index + 1])
    }
    loops.append((points, length))
    // Enough candidates to pick nine varied loops without searching the whole
    // network.
    if loops.count >= 260 || index > 6_000 { break }
}

// Keep the loops that are most different from each other, largest first.
var selected: [(points: [Point], length: Double)] = []
for candidate in loops.sorted(by: { $0.length > $1.length }) {
    // A loop has to have body in both directions, or it prints as a line.
    let latitudes = candidate.points.map(\.lat)
    let longitudes = candidate.points.map(\.lon)
    let height = (latitudes.max()! - latitudes.min()!) * 110_574
    let width = (longitudes.max()! - longitudes.min()!) * 111_320 * cos(latitudes.min()! * .pi / 180)
    guard min(width, height) > 120 else { continue }
    guard min(width, height) / max(width, height) > 0.55 else { continue }

    let overlaps = selected.contains { existing in
        let shared = Set(existing.points.map(\.key)).intersection(candidate.points.map(\.key)).count
        return Double(shared) / Double(min(existing.points.count, candidate.points.count)) > 0.4
    }
    if !overlaps {
        selected.append(candidate)
    }
    if selected.count >= 9 { break }
}

var swift = """
// Generated by design/make-demo-routes.swift. Do not edit by hand.
//
// The demo activities follow real mapped streets and paths from the bundled
// OpenStreetMap extract. Each route is a genuine closed loop in that network:
// the streets a runner would actually take around a block or a park.
// Data: (c) OpenStreetMap contributors, ODbL 1.0. See design/ATTRIBUTION.md.

enum DemoRoute {
    /// Closed loop -> coordinate pairs of latitude and longitude.
    static let loops: [[(latitude: Double, longitude: Double)]] = [
"""

for loop in selected {
    swift += "        [\n"
    for point in loop.points {
        swift += "            (\(point.lat), \(point.lon)),\n"
    }
    swift += "        ],\n"
}
swift += "    ]\n}\n"

try swift.write(to: URL(fileURLWithPath: arguments[2]), atomically: true, encoding: .utf8)
print("Wrote \(arguments[2]) with \(selected.count) loops")
for loop in selected {
    print(" - \(loop.points.count) points, \(Int(loop.length)) m")
}
