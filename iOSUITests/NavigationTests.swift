import XCTest

@MainActor
final class NavigationTests: XCTestCase {
    func testOfflineNavigationAndNowPlaying() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["Listen"].waitForExistence(timeout: 10))
        capture(app,"Home")
        app.tabBars.buttons["Library"].tap()
        XCTAssertTrue(app.navigationBars["Library"].exists)
        XCTAssertTrue(app.staticTexts["Your library is empty"].waitForExistence(timeout:3))
        capture(app,"Library")
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.descendants(matching:.any)["themePicker"].exists)
        capture(app,"Settings")
        XCTAssertTrue(app.buttons["miniPlayerOpen"].waitForExistence(timeout:5))
        app.buttons["miniPlayerOpen"].tap()
        XCTAssertTrue(app.staticTexts["Nothing playing"].waitForExistence(timeout: 3))
        capture(app,"Now Playing — empty library")
        app.buttons["Done"].tap()
        app.buttons["settingsSignalPath"].tap()
        XCTAssertTrue(app.navigationBars["Signal Path"].waitForExistence(timeout:5))
        XCTAssertTrue(app.descendants(matching:.any)["signalPathStatus"].exists)
        capture(app,"Signal Path — inactive session")
    }
    func testPrimaryControlLabelsAndTouchTarget() throws {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.navigationBars["Listen"].waitForExistence(timeout:10))
        let player = app.buttons["miniPlayerOpen"]
        XCTAssertTrue(player.waitForExistence(timeout:5))
        XCTAssertFalse(player.label.isEmpty)
        XCTAssertEqual(player.value as? String,"No track selected")
        XCTAssertGreaterThanOrEqual(player.frame.height,44)
        XCTAssertGreaterThanOrEqual(player.frame.width,44)
        try app.performAccessibilityAudit(for:.sufficientElementDescription)
    }
    func testEmptySearchMessageUsesActualQuery() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.navigationBars["Listen"].waitForExistence(timeout:10))
        app.tabBars.buttons["Library"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout:5))
        let query = "soundly-reference-no-match"
        search.tap(); search.typeText(query)
        let message = app.staticTexts.containing(NSPredicate(format:"label CONTAINS[c] %@ AND label CONTAINS %@","No Results",query)).firstMatch
        XCTAssertTrue(message.waitForExistence(timeout:5))
        XCTAssertFalse(app.staticTexts["Your library is empty"].exists)
        capture(app,"Library — unmatched local search")
    }
    private func capture(_ app:XCUIApplication,_ name:String) {
        let attachment = XCTAttachment(screenshot:app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
