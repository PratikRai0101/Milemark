import XCTest

/// The core loop, end to end: open a run, print the receipt, pull the paper
/// off, and land back in the archive.
///
/// The pauses are deliberate. This test is also what `design/record-demo.sh`
/// drives while it records the demo in the readme, and a demo that cuts
/// between beats is not a demo.
@MainActor
final class CoreLoopTests: XCTestCase {
    func testTheCoreLoop() {
        let app = XCUIApplication()
        app.launchArguments = ["-seedDemoData"]
        app.launch()

        // The archive.
        XCTAssertTrue(app.staticTexts["MILEMARK"].waitForExistence(timeout: 20))
        sleep(3)

        // Open a run.
        let route = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Interval")).firstMatch
        XCTAssertTrue(route.waitForExistence(timeout: 20))
        sleep(2)
        route.tap()

        // The receipt prints itself out of the tray.
        XCTAssertTrue(app.staticTexts["Printed record"].waitForExistence(timeout: 20))
        sleep(4)

        // The statistics.
        XCTAssertTrue(app.staticTexts["DISTANCE"].exists)
        sleep(3)

        // Scroll to the end of the paper, where the tear can begin.
        let receiptScroll = app.scrollViews.element(boundBy: max(app.scrollViews.count - 1, 0))
        for _ in 0..<10 {
            let grip = app.descendants(matching: .any).matching(identifier: "tear-grip").firstMatch
            if grip.exists && grip.label == "Pull to tear" { break }
            receiptScroll.swipeUp()
        }
        sleep(3)

        // Pull the paper off.
        let grip = app.descendants(matching: .any).matching(identifier: "tear-grip").firstMatch
        XCTAssertTrue(grip.waitForExistence(timeout: 10))
        let start = grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: 0, dy: 260))
        start.press(forDuration: 0.3, thenDragTo: end)
        sleep(4)

        // Back in the archive.
        XCTAssertTrue(app.staticTexts["MILEMARK"].waitForExistence(timeout: 20))
        sleep(2)
    }
}
