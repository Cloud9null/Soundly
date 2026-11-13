import XCTest

@MainActor final class PlayerRefinementTests:XCTestCase {
    private func openPlayer(large:Bool = false)->XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--soundly-fixtures"] + (large ? ["--soundly-large-type"] : [])
        app.launch()
        XCTAssertTrue(app.navigationBars["Listen"].waitForExistence(timeout:30))
        capture(app,large ? "Home — enlarged text" : "Home — native bottom accessory")
        app.tabBars.buttons["Library"].tap()
        XCTAssertTrue(app.staticTexts["libraryTrackCount"].waitForExistence(timeout:10))
        XCTAssertEqual(app.staticTexts["libraryTrackCount"].label,"3 songs")
        capture(app,large ? "Songs — enlarged text" : "Songs — numbered library")
        app.staticTexts["Reference 1"].firstMatch.tap()
        XCTAssertTrue(app.buttons["audioQualityButton"].waitForExistence(timeout:10))
        let toggle = app.buttons["transportToggle"]
        if toggle.label == "Pause" { toggle.tap() }
        return app
    }
    func testPopulatedFullscreenPlayerQualityArtworkAndQueue() {
        let app = openPlayer()
        XCTAssertTrue(app.staticTexts["Track 1 of 3"].exists)
        XCTAssertFalse(app.tabBars.buttons["Library"].isHittable,"Player must cover the root tab bar")
        assertFooter(app)
        capture(app,"Full-screen player — actual PCM24 reference")
        app.buttons["expandArtwork"].tap()
        XCTAssertTrue(app.buttons["closeArtwork"].waitForExistence(timeout:5))
        capture(app,"Immersive reference artwork")
        app.buttons["closeArtwork"].tap()
        app.buttons["audioQualityButton"].tap()
        XCTAssertTrue(app.navigationBars["Signal Path"].waitForExistence(timeout:5))
        XCTAssertTrue(app.descendants(matching:.any)["rateSummary"].exists)
        capture(app,"Live quality report — simulator observations")
        app.buttons["closeQuality"].tap()
        app.buttons["openQueue"].tap()
        XCTAssertTrue(app.navigationBars["Queue"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts["Reference 3"].exists)
        capture(app,"Numbered playback queue")
    }
    func testPlayerFooterAtAccessibilityTextSize() {
        let app = openPlayer(large:true)
        XCTAssertGreaterThan(app.staticTexts["Reference 1"].firstMatch.frame.height,35,"Full-screen presentation must inherit the controlled accessibility text size")
        assertFooter(app)
        capture(app,"Player at accessibility2 text size")
    }
    func testDuplicateScanReviewAndRemoval() {
        let app = XCUIApplication(); app.launchArguments = ["--soundly-fixtures","--soundly-duplicates"]; app.launch()
        XCTAssertTrue(app.navigationBars["Listen"].waitForExistence(timeout:30))
        app.tabBars.buttons["Settings"].tap()
        app.buttons["manageDuplicates"].tap()
        XCTAssertTrue(app.navigationBars["Duplicates"].waitForExistence(timeout:5))
        app.buttons["scanDuplicates"].tap()
        XCTAssertTrue(app.buttons["removeDuplicates"].waitForExistence(timeout:30))
        capture(app,"Byte-identical duplicate review — test files only")
        app.buttons["removeDuplicates"].tap()
        app.buttons["Remove extra copies"].tap()
        let result = app.staticTexts["duplicateResult"]
        XCTAssertTrue(result.waitForExistence(timeout:30)); XCTAssertTrue(result.label.contains("Removed 1"))
        app.tabBars.buttons["Library"].tap()
        XCTAssertTrue(app.staticTexts["libraryTrackCount"].waitForExistence(timeout:5))
        XCTAssertEqual(app.staticTexts["libraryTrackCount"].label,"2 songs")
    }
    private func assertFooter(_ app:XCUIApplication) {
        let frame = app.frame
        for id in ["shuffleButton","repeatButton","openQueue","playbackMenu","nowPlayingDone","favoriteToggle","transportToggle"] {
            let button = app.buttons[id]
            XCTAssertTrue(button.exists); XCTAssertTrue(button.isHittable)
            // AX converts screen coordinates through floating-point transforms; 44 can return 43.99999999999997.
            // One millionth of a point tolerates numeric roundoff while retaining the 44-point requirement.
            let coordinateTolerance = 0.000001
            XCTAssertGreaterThanOrEqual(button.frame.height+coordinateTolerance,44)
            XCTAssertGreaterThanOrEqual(button.frame.width+coordinateTolerance,44)
            XCTAssertGreaterThanOrEqual(button.frame.minX,frame.minX); XCTAssertLessThanOrEqual(button.frame.maxX,frame.maxX)
            XCTAssertLessThanOrEqual(button.frame.maxY,frame.maxY)
        }
        XCTAssertLessThanOrEqual(app.buttons["transportToggle"].frame.maxY,app.buttons["shuffleButton"].frame.minY-8,"Primary transport must remain above the glass footer")
    }
    private func capture(_ app:XCUIApplication,_ title:String) {
        let attachment = XCTAttachment(screenshot:app.screenshot()); attachment.name = title; attachment.lifetime = .keepAlways; add(attachment)
    }
}
