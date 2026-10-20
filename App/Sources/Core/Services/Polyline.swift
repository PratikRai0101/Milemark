import CoreLocation
import Foundation

/// Decodes the encoded polyline that Strava returns for a route.
///
/// The format is Google's encoded polyline: the points are turned into one
/// string of characters, and each character carries five bits of a delta from
/// the previous point. It is a compact way of shipping a route, and it has to
/// be decoded before the route can be drawn.
///
/// A route that fails to decode is not a route, so a malformed polyline
/// returns nothing rather than a partial track that would look like a
/// deliberate shape.
public enum Polyline {
    /// The characters that carry no information, used to break a route into
    /// separate stretches.
    private static let separators: Set<Character> = ["|", "?", ";", ",", "\n", "\t", " ", "\r"]

    /// Decodes an encoded polyline into coordinates.
    public static func decode(_ encoded: String) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        var index = encoded.startIndex
        var latitude = 0
        var longitude = 0

        while index < encoded.endIndex {
            let character = encoded[index]
            if separators.contains(character) {
                index = encoded.index(after: index)
                continue
            }

            guard let (deltaLatitude, nextIndex) = decodeValue(in: encoded, from: index) else {
                // A malformed polyline is not worth half a route.
                return []
            }
            guard let (deltaLongitude, finalIndex) = decodeValue(in: encoded, from: nextIndex) else {
                return []
            }
            index = finalIndex

            latitude += deltaLatitude
            longitude += deltaLongitude
            coordinates.append(
                CLLocationCoordinate2D(
                    latitude: Double(latitude) / 100_000,
                    longitude: Double(longitude) / 100_000
                )
            )
        }

        return coordinates
    }

    /// Decodes one signed value.
    ///
    /// The value is stored in five-bit groups, each with a continuation bit
    /// set when more groups follow. The least significant bit of the result
    /// holds the sign, and the rest is the magnitude.
    ///
    /// A value that runs off the end of the string is not a value. Half a
    /// coordinate would put the route in the wrong place, so the whole
    /// polyline is rejected.
    private static func decodeValue(in encoded: String, from start: String.Index) -> (Int, String.Index)? {
        var result = 0
        var shift = 0
        var index = start

        while true {
            guard index < encoded.endIndex else { return nil }
            let byte = encoded[index].asciiValue ?? 0
            guard byte >= 63 else { return nil }
            let value = Int(byte) - 63
            result |= (value & 0x1F) << shift
            shift += 5
            index = encoded.index(after: index)
            // A byte below 0x20 has the continuation bit clear, so the value
            // is finished.
            if value < 0x20 { break }
        }

        let delta = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
        return (delta, index)
    }
}
