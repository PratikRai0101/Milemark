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
        if ProcessInfo.processInfo.environment["MILEMARK_SHOWCASE"] == "1" {
            showcaseAllFeatures()
            return
        }
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

    /// Recording-only branch: the host supplies simulated GPS and changes
    /// system text size at the marked beats. Ordinary CI keeps the short core
    /// loop above and does not depend on external simulator controls.
    private func showcaseAllFeatures() {
        let app = XCUIApplication()
        app.launchArguments = ["-seedDemoData", "-demoPhoto"]
        app.launch()
        let route = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Interval")).firstMatch
        XCTAssertTrue(route.waitForExistence(timeout: 20))
        mark("BEGIN")
        sleep(3)
        mark("OPEN")
        route.tap()
        XCTAssertTrue(app.staticTexts["Printed record"].waitForExistence(timeout: 20))
        hold("RECEIPT", seconds: 3)

        chooseGraphic("ascii", in: app)
        XCTAssertTrue(app.otherElements["Route drawn with letters"].exists)
        hold("ASCII", seconds: 3)

        chooseGraphic("pace", in: app)
        hold("PACE", seconds: 2)
        let chart = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Pace per kilometre")).firstMatch
        XCTAssertTrue(chart.waitForExistence(timeout: 10))
        mark("SCRUB")
        chart.coordinate(withNormalizedOffset: CGVector(dx: 0.18, dy: 0.5))
            .press(forDuration: 0.2,
                   thenDragTo: chart.coordinate(withNormalizedOffset: CGVector(dx: 0.78, dy: 0.5)),
                   withVelocity: .slow, thenHoldForDuration: 1.5)

        chooseGraphic("photo", in: app)
        XCTAssertTrue(app.otherElements["Photographic print treatment"].exists)
        hold("PHOTO", seconds: 3)
        tap(app.buttons["Print the photo as DITHER"])
        hold("DITHER", seconds: 2)
        tap(app.buttons["Print the photo as POSTER"])
        hold("POSTER", seconds: 3)
        chooseGraphic("route", in: app)

        tap(app.buttons["Share"])
        XCTAssertTrue(app.staticTexts["Share preview"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.switches["Trim route ends"].exists)
        hold("SHARE", seconds: 4)
        tap(app.buttons["Done"])

        // The host changes the actual system setting, not a mock layout or
        // a relaunch into a second app instance. The sheet stays on screen.
        hold("LARGE_TEXT", seconds: 5)
        XCTAssertGreaterThan(app.buttons["Tear off"].frame.midY, app.buttons["Save"].frame.midY + 20)
        hold("NORMAL_TEXT", seconds: 2)

        mark("SCROLL")
        let scroll = app.scrollViews.element(boundBy: max(app.scrollViews.count - 1, 0))
        let grip = app.descendants(matching: .any).matching(identifier: "tear-grip").firstMatch
        for _ in 0..<3 {
            if grip.exists && grip.label == "Pull to tear" { break }
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.68))
                .press(forDuration: 0.15,
                       thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)),
                       withVelocity: .slow, thenHoldForDuration: 0.25)
        }
        XCTAssertEqual(grip.label, "Pull to tear")
        hold("FOOTER", seconds: 2)
        mark("TEAR")
        let start = grip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.25, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 110)),
                    withVelocity: .slow, thenHoldForDuration: 0.15)
        XCTAssertTrue(route.waitForExistence(timeout: 10))
        XCTAssertTrue(route.isHittable)
        mark("RETURN")

        tap(app.tabBars.buttons["Kept"])
        XCTAssertTrue(app.navigationBars["Kept"].waitForExistence(timeout: 10))
        hold("KEPT", seconds: 3)
        tap(app.tabBars.buttons["Runs"])
        tap(app.buttons["About Milemark"])
        XCTAssertTrue(app.segmentedControls["map-style-picker"].waitForExistence(timeout: 10))
        hold("SETTINGS", seconds: 3)
        tap(app.buttons["Import from Strava"])
        XCTAssertTrue(app.buttons["connect-strava"].waitForExistence(timeout: 10))
        hold("IMPORT", seconds: 3)
        // Do not claim a live Strava connection: this is the consent screen,
        // with placeholder build credentials, exactly as in the screenshots.
        tap(app.navigationBars["Import from Strava"].buttons.element(boundBy: 0))
        tap(app.navigationBars["Milemark"].buttons.element(boundBy: 0))

        tap(app.tabBars.buttons["Record"])
        XCTAssertTrue(app.buttons["Start run"].waitForExistence(timeout: 10))
        hold("MAP_READY", seconds: 3)
        tap(app.buttons["Start run"])
        hold("TRACKING", seconds: 10)
        XCTAssertTrue(app.buttons["Pause"].exists)
        // The map must show a genuine simulated track, not a zero-distance
        // blank map. This is in addition to the host's signal-pixel check.
        XCTAssertFalse(app.staticTexts["0.00"].exists)
        tap(app.buttons["Pause"])
        hold("PAUSED", seconds: 2)
        tap(app.buttons["Resume"])
        hold("RESUMED", seconds: 2)
        tap(app.buttons["Finish"])
        XCTAssertTrue(app.staticTexts["Review run"].waitForExistence(timeout: 10))
        hold("REVIEW", seconds: 3)
        tap(app.buttons["Cancel"])
        tap(app.tabBars.buttons["Runs"])
        XCTAssertTrue(route.waitForExistence(timeout: 10))
        XCTAssertTrue(route.isHittable)
        hold("FINAL", seconds: 3)
        mark("END")
    }

    private func hold(_ beat: String, seconds: UInt32) {
        mark(beat)
        sleep(seconds)
    }

    private func tap(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 10))
        element.tap()
    }

    private func chooseGraphic(_ graphic: String, in app: XCUIApplication) {
        tap(app.buttons["graphic-badge"])
        tap(app.buttons["graphic-\(graphic)"])
    }
}
