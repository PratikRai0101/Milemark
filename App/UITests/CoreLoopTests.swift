import XCTest

/// A single continuous showcase of the core loop. The recorder trims only at
/// BEGIN/END markers, never in the middle of a transition. The same test also
/// verifies the real gestures; no demo-only animation or playback is involved.
@MainActor
final class CoreLoopTests: XCTestCase {
    private func mark(_ beat: String) {
        print("MILEMARK_DEMO_\(beat) \(Date().timeIntervalSince1970)")
    }

    func testTheCoreLoop() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-seedDemoData", "-dynamicTypeSize=large"]
        app.launch()

        XCTAssertTrue(app.staticTexts["MILEMARK"].waitForExistence(timeout: 20))
        let route = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Interval")).firstMatch
        XCTAssertTrue(route.waitForExistence(timeout: 20))

        mark("BEGIN")
        // Let the audience read the archive before anything moves.
        sleep(3)
        mark("OPEN")
        route.tap()

        XCTAssertTrue(app.staticTexts["Printed record"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["DISTANCE"].exists)
        mark("RECEIPT")
        // Includes the feed settling, then an uninterrupted look at the route
        // and statistics. Do not cut away as soon as the paper finishes printing.
        sleep(8)

        mark("SCROLL")
        let receiptScroll = app.scrollViews.element(boundBy: max(app.scrollViews.count - 1, 0))
        for _ in 0..<3 {
            let grip = app.descendants(matching: .any).matching(identifier: "tear-grip").firstMatch
            if grip.exists && grip.label == "Pull to tear" { break }
            let start = receiptScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.68))
            let end = receiptScroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.40))
            // A deliberate drag, not a flick with a sudden inertial stop.
            start.press(forDuration: 0.15, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.25)
        }
        let grip = app.descendants(matching: .any).matching(identifier: "tear-grip").firstMatch
        XCTAssertTrue(grip.waitForExistence(timeout: 10))
        XCTAssertEqual(grip.label, "Pull to tear")
        mark("FOOTER")
        sleep(4)

        mark("TEAR")
        let start = grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        // Cross the 72 pt threshold without dragging outside the screen.
        let end = start.withOffset(CGVector(dx: 0, dy: 110))
        start.press(forDuration: 0.25, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.15)

        // The receipt also prints MILEMARK, so that word alone is not proof
        // of returning to the archive. Check the actual destination.
        XCTAssertTrue(route.waitForExistence(timeout: 20))
        XCTAssertTrue(route.isHittable)
        XCTAssertFalse(app.staticTexts["Printed record"].exists)
        mark("RETURN")
        // Hold the landing too: the loop must not end halfway through the zoom.
        sleep(4)
        mark("END")
    }
}
