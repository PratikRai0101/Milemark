import XCTest

/// End-to-end tests for the interactions that a screenshot cannot show:
/// opening a receipt, changing the graphic, pulling the paper, and sharing.
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

        let grip = button(startingWith: "Pull to tear off")
        XCTAssertTrue(waitFor(grip))
        let start = grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: 0, dy: 20))
        start.press(forDuration: 0.2, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)

        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/ui-tear-short.png"))
        // Released short of the threshold, the receipt is still on screen.
        XCTAssertTrue(app.staticTexts["Run receipt"].exists)
        XCTAssertTrue(app.staticTexts["INTERVAL"].exists)
    }

    func testPullingThePaperPastTheThresholdCollectsIt() {
        let route = button(startingWith: "Interval")
        XCTAssertTrue(waitFor(route))
        route.tap()
        XCTAssertTrue(waitFor(app.staticTexts["Run receipt"]))

        let grip = button(startingWith: "Pull to tear off")
        XCTAssertTrue(waitFor(grip))
        let start = grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: 0, dy: 160))
        start.press(forDuration: 0.2, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)

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
