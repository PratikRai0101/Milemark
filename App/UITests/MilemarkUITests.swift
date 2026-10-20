import XCTest

/// End-to-end tests for the interactions that a screenshot cannot show:
/// opening a receipt, changing the graphic, pulling the paper, tearing it
/// off, and sharing.
@MainActor
final class MilemarkUITests: XCTestCase {
    private var app: XCUIApplication!

    /// Launches the app with the sample activities loaded.
    private func launchApp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-seedDemoData"]
        app.launch()
    }

    /// Finds a button whose label begins with the given text.
    private func button(startingWith text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", text)).firstMatch
    }

    /// Finds the tear grip wherever it sits in the tree.
    private var tearGrip: XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "tear-grip")
            .firstMatch
    }

    /// Waits for an element to appear.
    @discardableResult
    private func waitFor(_ element: XCUIElement, _ timeout: TimeInterval = 20) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    /// Scrolls the receipt to the end, where the tear grip sits.
    ///
    /// At the end of the paper there is nothing left to scroll, so a pull
    /// down is unambiguously a pull on the paper rather than a scroll. The
    /// grip says so, and the tear only engages there.
    @discardableResult
    private func scrollToTearGrip() -> Bool {
        // The receipt is pushed on top of the archive, so the last scroll
        // view in the tree is the receipt's.
        let receiptScroll = app.scrollViews.element(boundBy: max(app.scrollViews.count - 1, 0))
        for _ in 0..<15 {
            let grip = tearGrip
            guard grip.exists else { return false }
            // The grip only offers the pull once the receipt is at the end.
            if grip.label == "Pull to tear" { return true }
            receiptScroll.swipeUp()
        }
        return tearGrip.label == "Pull to tear"
    }

    func testArchiveOpensAReceipt() {
        launchApp()
        XCTAssertTrue(waitFor(app.staticTexts["MILEMARK"]))

        let route = button(startingWith: "Interval")
        XCTAssertTrue(waitFor(route))
        route.tap()

        XCTAssertTrue(waitFor(app.staticTexts["Printed record"]))
        XCTAssertTrue(app.staticTexts["INTERVAL"].exists)
        XCTAssertTrue(app.staticTexts["9.34 KM"].exists)
        XCTAssertTrue(app.staticTexts["PRINTED ON THIS PHONE"].exists)
    }

    func testGraphicPickerChangesTheTreatment() {
        launchApp()
        let route = button(startingWith: "Interval")
        XCTAssertTrue(waitFor(route))
        route.tap()
        XCTAssertTrue(waitFor(app.staticTexts["Printed record"]))

        // The labelled badge opens the explicit chooser.
        let badge = button(startingWith: "Change receipt graphic")
        XCTAssertTrue(waitFor(badge))
        badge.tap()

        let ascii = button(startingWith: "ASCII MAP")
        XCTAssertTrue(waitFor(ascii))
        ascii.tap()

        XCTAssertTrue(waitFor(app.staticTexts["ASCII MAP"]))
    }

    /// A pull short of the threshold must not tear the receipt off.
    ///
    /// The threshold itself is covered by `TearRuleTests`. The state of a
    /// pull in progress cannot be observed through the UI test API, so only
    /// the outcome is asserted here.
    func testPullingThePaperShortOfTheThresholdPutsItBack() {
        launchApp()
        let route = button(startingWith: "Interval")
        XCTAssertTrue(waitFor(route))
        route.tap()
        XCTAssertTrue(waitFor(app.staticTexts["Printed record"]))

        let grip = tearGrip
        XCTAssertTrue(waitFor(grip))
        XCTAssertTrue(scrollToTearGrip())
        let start = grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: 0, dy: 20))
        start.press(forDuration: 0.2, thenDragTo: end)

        // Released short of the threshold, the receipt is still on screen and
        // the grip is still there to pull again.
        XCTAssertTrue(app.staticTexts["Printed record"].exists)
        XCTAssertTrue(app.staticTexts["INTERVAL"].exists)
        XCTAssertTrue(tearGrip.exists)
    }

    func testTearingOffCollectsTheReceipt() {
        launchApp()
        let route = button(startingWith: "Interval")
        XCTAssertTrue(waitFor(route))
        route.tap()
        XCTAssertTrue(waitFor(app.staticTexts["Printed record"]))

        let tear = button(startingWith: "Tear off")
        XCTAssertTrue(waitFor(tear))
        tear.tap()

        // The receipt is collected and the archive returns.
        XCTAssertTrue(waitFor(app.staticTexts["MILEMARK"]))
    }

    func testSharePreviewOpens() {
        launchApp()
        let route = button(startingWith: "Interval")
        XCTAssertTrue(waitFor(route))
        route.tap()
        XCTAssertTrue(waitFor(app.staticTexts["Printed record"]))

        let share = button(startingWith: "Share")
        XCTAssertTrue(waitFor(share))
        share.tap()

        XCTAssertTrue(waitFor(app.staticTexts["Share preview"]))
        XCTAssertTrue(app.staticTexts["Trim route ends"].exists)
        XCTAssertTrue(app.staticTexts["A ROUTE, PRINTED"].exists)
    }
}
