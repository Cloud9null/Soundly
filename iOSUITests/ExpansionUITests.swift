import XCTest

@MainActor final class ExpansionUITests:XCTestCase {
    func testSmartQueueAndOfflineLyricsMenu() {
        let app = XCUIApplication();app.launchArguments = ["--soundly-fixtures"];app.launch()
        XCTAssertTrue(app.navigationBars["Listen"].waitForExistence(timeout:30))
        app.tabBars.buttons["Library"].tap();app.buttons["Smart Playlists"].tap()
        XCTAssertTrue(app.navigationBars["Smart Playlists"].waitForExistence(timeout:5))
        let rule = app.buttons["smartRule-Never played"];XCTAssertTrue(rule.waitForExistence(timeout:5));rule.tap()
        XCTAssertTrue(app.navigationBars["Never played"].waitForExistence(timeout:5))
        app.staticTexts["Reference 1"].firstMatch.tap()
        let miniPlayer = app.buttons["miniPlayerOpen"];XCTAssertTrue(miniPlayer.waitForExistence(timeout:10))
        let selected = NSPredicate(format:"value BEGINSWITH %@ AND hittable == true","Reference 1")
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:selected,object:miniPlayer)],timeout:10),.completed)
        miniPlayer.coordinate(withNormalizedOffset:CGVector(dx:0.2,dy:0.5)).tap()
        XCTAssertTrue(app.buttons["playbackMenu"].waitForExistence(timeout:10))
        app.buttons["playbackMenu"].tap();app.buttons["Lyrics"].tap()
        XCTAssertTrue(app.navigationBars["Lyrics"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts["Your words, offline"].waitForExistence(timeout:5))
        let shot = XCTAttachment(screenshot:app.screenshot());shot.name = "Offline lyrics empty state";shot.lifetime = .keepAlways;add(shot)
    }
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
