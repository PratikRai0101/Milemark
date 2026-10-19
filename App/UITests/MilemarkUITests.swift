import XCTest

/// End-to-end tests for the interactions that a screenshot cannot show:
/// opening a receipt, changing the graphic, pulling the paper, and sharing.
@MainActor
final class MilemarkUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-seedDemoData"]
        app.launch()
    }

    /// Finds a button whose label begins with the given text.
    private func button(startingWith text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", text)).firstMatch
    }

    /// Waits for an element to appear.
    @discardableResult
    private func waitFor(_ element: XCUIElement, _ timeout: TimeInterval = 20) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    /// Finds the tear grip wherever it sits in the tree.
    private var tearGrip: XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "tear-grip")
            .firstMatch
    }

    /// Scrolls the receipt to the end, where the tear grip sits.
    ///
    /// At the end of the paper there is nothing left to scroll, so a pull
    /// down is unambiguously a pull on the paper rather than a scroll.
    @discardableResult
    private func scrollToTearGrip() -> Bool {
        let bar = app.descendants(matching: .any)
            .matching(identifier: "receipt-actions")
            .firstMatch
        for _ in 0..<12 {
            let grip = tearGrip
            guard grip.exists else { return false }
            let clearOfBar = !bar.exists || grip.frame.maxY <= bar.frame.minY
            if clearOfBar, grip.frame.minY > 120, grip.isHittable { return true }
            app.scrollViews.firstMatch.swipeUp()
        }
        return false
    }

    func testArchiveOpensAReceipt() {
        XCTAssertTrue(waitFor(app.staticTexts["MILEMARK"]))

        let route = button(startingWith: "Interval")
        XCTAssertTrue(waitFor(route))
        route.tap()

        XCTAssertTrue(waitFor(app.staticTexts["Run receipt"]))
        XCTAssertTrue(app.staticTexts["INTERVAL"].exists)
        XCTAssertTrue(app.staticTexts["9.34 KM"].exists)
        XCTAssertTrue(app.staticTexts["A route worth keeping."].exists)
    }

    func testGraphicPickerChangesTheTreatment() {
        let route = button(startingWith: "Interval")
        XCTAssertTrue(waitFor(route))
        route.tap()
        XCTAssertTrue(waitFor(app.staticTexts["Run receipt"]))

        // The labelled badge opens the explicit chooser.
        let badge = button(startingWith: "Change receipt graphic")
        XCTAssertTrue(waitFor(badge))
        badge.tap()

        let ascii = button(startingWith: "ASCII MAP")
        XCTAssertTrue(waitFor(ascii))
        ascii.tap()

        XCTAssertTrue(waitFor(app.staticTexts["ASCII MAP"]))
    }

    func testPullingThePaperShortOfTheThresholdPutsItBack() {
        let route = button(startingWith: "Interval")
        XCTAssertTrue(waitFor(route))
        route.tap()
        XCTAssertTrue(waitFor(app.staticTexts["Run receipt"]))

        let grip = tearGrip
        XCTAssertTrue(waitFor(grip))
        XCTAssertTrue(scrollToTearGrip())
        let start = grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: 0, dy: 20))
        start.press(forDuration: 0.2, thenDragTo: end)

        // Released short of the threshold, the receipt is still on screen and
        // the grip is still there to pull again.
        XCTAssertTrue(app.staticTexts["Run receipt"].exists)
        XCTAssertTrue(app.staticTexts["INTERVAL"].exists)
        XCTAssertTrue(tearGrip.exists)
    }

    func testTearingOffCollectsTheReceipt() {
        let route = button(startingWith: "Interval")
        XCTAssertTrue(waitFor(route))
        route.tap()
        XCTAssertTrue(waitFor(app.staticTexts["Run receipt"]))

        let tear = button(startingWith: "Tear off")
        XCTAssertTrue(waitFor(tear))
        tear.tap()

        // The receipt is collected and the archive returns.
        XCTAssertTrue(waitFor(app.staticTexts["MILEMARK"]))
    }

    func testPullingThePaperPastTheThresholdCollectsIt() {
        let route = button(startingWith: "Interval")
        XCTAssertTrue(waitFor(route))
        route.tap()
        XCTAssertTrue(waitFor(app.staticTexts["Run receipt"]))

        let grip = tearGrip
        XCTAssertTrue(waitFor(grip))
        XCTAssertTrue(scrollToTearGrip())
        let start = grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: 0, dy: 100))
        start.press(forDuration: 0.2, thenDragTo: end)

        // Past the threshold the receipt is collected and the archive returns.
        XCTAssertTrue(waitFor(app.staticTexts["MILEMARK"]))
    }

    func testSharePreviewOpens() {
        let route = button(startingWith: "Interval")
        XCTAssertTrue(waitFor(route))
        route.tap()
        XCTAssertTrue(waitFor(app.staticTexts["Run receipt"]))

        let share = button(startingWith: "Share")
        XCTAssertTrue(waitFor(share))
        share.tap()

        XCTAssertTrue(waitFor(app.staticTexts["Share preview"]))
        XCTAssertTrue(app.staticTexts["Trim route ends"].exists)
        XCTAssertTrue(app.staticTexts["A ROUTE WORTH KEEPING"].exists)
    }
}
