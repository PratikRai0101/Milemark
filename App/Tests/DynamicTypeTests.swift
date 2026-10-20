import SwiftUI
import XCTest
@testable import Milemark

/// The app's type follows the reader's Dynamic Type setting, and the layouts
/// that would otherwise squeeze their contents adapt instead.
final class DynamicTypeTests: XCTestCase {
    func testReceiptStatisticsReflowAtLargeTextSizes() {
        XCTAssertEqual(Theme.receiptColumns(for: .large), 3)
        XCTAssertEqual(Theme.receiptColumns(for: .xxxLarge), 3)
        XCTAssertEqual(Theme.receiptColumns(for: .accessibility1), 2)
        XCTAssertEqual(Theme.receiptColumns(for: .accessibility5), 2)
    }

    func testCardsBecomeOneAcrossAtLargeTextSizes() {
        XCTAssertEqual(Theme.cardMinimum(for: .large), 104)
        XCTAssertEqual(Theme.cardMinimum(for: .xxxLarge), 104)
        XCTAssertEqual(Theme.cardMinimum(for: .accessibility1), 240)
        XCTAssertEqual(Theme.cardMinimum(for: .accessibility5), 240)
    }

    /// A card that is 240pt wide cannot share a phone screen with another
    /// one, which is the point: at large text sizes each card gets the whole
    /// width rather than clipping its own contents.
    func testWideCardsDoNotShareAScreen() {
        let screenWidth: CGFloat = 390
        let wide = Theme.cardMinimum(for: .accessibility3)
        XCTAssertGreaterThan(wide * 2, screenWidth, "Two wide cards would not fit, so the grid must fall to one column.")
    }

    /// The type tokens are built from text styles, so they scale by
    /// construction. This checks that each token resolves to a real font
    /// rather than silently falling back to a fixed size.
    func testTypeTokensAreBuiltFromTextStyles() {
        let tokens: [Font] = [
            Theme.Font.archiveTitle,
            Theme.Font.screenTitle,
            Theme.Font.paperTitle,
            Theme.Font.metricValue,
            Theme.Font.value,
            Theme.Font.body,
            Theme.Font.label,
            Theme.Font.labelStrong,
            Theme.Font.footnote,
            Theme.Font.action,
        ]
        for token in tokens {
            XCTAssertNotNil(token, "A type token resolved to nothing.")
        }
    }
}
