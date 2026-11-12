import XCTest

@MainActor
final class NavigationTests: XCTestCase {
    func testOfflineNavigationAndNowPlaying() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["Listen"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Library"].tap()
        XCTAssertTrue(app.navigationBars["Library"].exists)
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.descendants(matching:.any)["themePicker"].exists)
        XCTAssertTrue(app.buttons["miniPlayerOpen"].waitForExistence(timeout:5))
        app.buttons["miniPlayerOpen"].tap()
        XCTAssertTrue(app.staticTexts["Nothing playing"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()
    }
}
