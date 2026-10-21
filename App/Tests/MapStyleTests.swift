import MapKit
import XCTest
@testable import Milemark

/// The map style is the set of decisions about how loud the basemap is and
/// what is drawn on top of it.
final class MapStyleTests: XCTestCase {
    func testTheMilemarkStyleIsQuiet() {
        let configuration = MapStyle.milemark.configuration() as? MKStandardMapConfiguration
        XCTAssertNotNil(configuration, "The style should be built from Apple's standard map.")
        XCTAssertEqual(configuration?.emphasisStyle, .muted)
        XCTAssertEqual(configuration?.elevationStyle, .flat)
        XCTAssertEqual(configuration?.showsTraffic, false)
        XCTAssertFalse(
            configuration?.pointOfInterestFilter?.includes(.restaurant) ?? true,
            "A restaurant pin is not a run."
        )
    }

    func testTheStandardStyleLeavesTheMapAlone() {
        let configuration = MapStyle.standard.configuration() as? MKStandardMapConfiguration
        XCTAssertNotNil(configuration)
        XCTAssertEqual(configuration?.emphasisStyle, .default)
        XCTAssertEqual(configuration?.showsTraffic, true)
        XCTAssertTrue(
            configuration?.pointOfInterestFilter?.includes(.restaurant) ?? false
        )
    }

    /// Only the app's own style inks the route and draws the marks.
    func testOnlyTheAppStyleDrawsItsOwnRoute() {
        XCTAssertTrue(MapStyle.milemark.drawsItsOwnRoute)
        XCTAssertFalse(MapStyle.standard.drawsItsOwnRoute)
    }
}
