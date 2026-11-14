import XCTest

@MainActor final class ExpansionUITests:XCTestCase {
    func testPlaylistCreationTrackSelectionAndPersistence() {
        let app = XCUIApplication(); app.launchArguments = ["--soundly-fixtures"]; app.launch()
        XCTAssertTrue(app.navigationBars["Listen"].waitForExistence(timeout:30))
        app.tabBars.buttons["Library"].tap(); app.buttons["Playlists"].tap()
        let name = "Travel-"+String(UUID().uuidString.prefix(6))
        app.textFields["playlistName"].tap(); app.textFields["playlistName"].typeText(String(name))
        app.buttons["createPlaylist"].tap(); app.buttons[String(name)].tap()
        XCTAssertTrue(app.navigationBars[String(name)].waitForExistence(timeout:5))
        app.buttons.containing(NSPredicate(format:"label CONTAINS %@","Reference 1")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format:"label CONTAINS[c] %@","Tracks · 1")).firstMatch.exists)
        app.terminate(); app.launch(); XCTAssertTrue(app.navigationBars["Listen"].waitForExistence(timeout:30))
        app.tabBars.buttons["Library"].tap(); app.buttons["Playlists"].tap()
        XCTAssertTrue(app.buttons[String(name)].waitForExistence(timeout:5))
    }
}
