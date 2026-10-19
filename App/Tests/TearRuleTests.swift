import XCTest
@testable import Milemark

/// The rule for pulling a receipt off its slot.
final class TearRuleTests: XCTestCase {
    func testAShortPullDoesNotTear() {
        XCTAssertFalse(TearRule.shouldTear(translation: 0))
        XCTAssertFalse(TearRule.shouldTear(translation: 20))
        XCTAssertFalse(TearRule.shouldTear(translation: TearRule.threshold))
    }

    func testALongPullTears() {
        XCTAssertTrue(TearRule.shouldTear(translation: TearRule.threshold + 1))
        XCTAssertTrue(TearRule.shouldTear(translation: 200))
    }

    func testProgressIsClampedToTheTravel() {
        XCTAssertEqual(TearRule.progress(for: 0), 0)
        XCTAssertEqual(TearRule.progress(for: 45), 0.5, accuracy: 0.001)
        XCTAssertEqual(TearRule.progress(for: 90), 1, accuracy: 0.001)
        // Pulling further than the travel does not push the paper further.
        XCTAssertEqual(TearRule.progress(for: 500), 1, accuracy: 0.001)
        // Pulling upwards does not move the paper either.
        XCTAssertEqual(TearRule.progress(for: -30), 0, accuracy: 0.001)
    }
}
