import XCTest

@MainActor final class ExpansionUITests:XCTestCase {
    func testSyncedLyricsShortcutFromNowPlaying() {
        let app = XCUIApplication()
        app.launchArguments = ["--soundly-fixtures", "--soundly-lyrics"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Listen"].waitForExistence(timeout: 30))
        app.tabBars.buttons["Library"].tap()
        app.staticTexts["Reference 1"].firstMatch.tap()

        let lyrics = app.buttons["openLyrics"]
        XCTAssertTrue(lyrics.waitForExistence(timeout: 10))
        lyrics.tap()
        XCTAssertTrue(app.staticTexts["Synced Lyrics"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["transportToggle"].isHittable)
        XCTAssertTrue(app.buttons["Opening line"].exists)
        app.buttons["Second line"].tap()
        let activeLine = NSPredicate(format: "value == %@", "Current line")
        let highlight = XCTNSPredicateExpectation(predicate: activeLine, object: app.buttons["Second line"])
        XCTAssertEqual(XCTWaiter.wait(for: [highlight], timeout: 8), .completed)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Synced lyrics"
        shot.lifetime = .keepAlways
        add(shot)
        lyrics.tap()
        XCTAssertTrue(app.buttons["expandArtwork"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Synced Lyrics"].exists)
    }
    func testPlaylistCreationTrackSelectionAndPersistence() {
        let app = XCUIApplication(); app.launchArguments = ["--soundly-fixtures"]; app.launch()
        XCTAssertTrue(app.navigationBars["Listen"].waitForExistence(timeout:30))
        app.tabBars.buttons["Library"].tap()
        app.buttons["libraryAdd"].tap()
        app.buttons["New playlist"].tap()
        XCTAssertTrue(app.navigationBars["Playlists"].waitForExistence(timeout: 8))
        let name = "Travel-"+String(UUID().uuidString.prefix(6))
        app.textFields["playlistName"].tap(); app.textFields["playlistName"].typeText(String(name))
        app.buttons["createPlaylist"].tap(); app.buttons[String(name)].tap()
        XCTAssertTrue(app.navigationBars[String(name)].waitForExistence(timeout:5))
        XCTAssertTrue(app.buttons["Export M3U8"].exists)
        app.buttons["playlistAddSongs"].tap()
        XCTAssertTrue(app.navigationBars["Add songs"].waitForExistence(timeout: 5))
        app.buttons.containing(NSPredicate(format:"label CONTAINS %@","Reference 1")).firstMatch.tap()
        app.buttons.containing(NSPredicate(format:"label CONTAINS %@","Reference 2")).firstMatch.tap()
        app.buttons["addSelectedSongs"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format:"label CONTAINS[c] %@","Tracks · 2")).firstMatch.waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Playlist after adding two tracks"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.terminate(); app.launch(); XCTAssertTrue(app.navigationBars["Listen"].waitForExistence(timeout:30))
        app.tabBars.buttons["Library"].tap(); app.buttons["libraryBrowse"].tap(); app.buttons["Playlists"].tap()
        XCTAssertTrue(app.buttons[String(name)].waitForExistence(timeout:5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.navigationBars["Listen"].waitForExistence(timeout: 30))
        app.tabBars.buttons["Library"].tap()
        let addFromLibrary = app.buttons.matching(identifier: "libraryAddToPlaylist").matching(NSPredicate(format: "label == %@", "Add Reference 3 to playlist")).firstMatch
        XCTAssertTrue(addFromLibrary.waitForExistence(timeout: 5))
        addFromLibrary.tap()
        XCTAssertTrue(app.navigationBars["Add to playlist"].waitForExistence(timeout: 5))
        app.buttons[String(name)].tap()
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))
        app.buttons["libraryBrowse"].tap()
        app.buttons["Playlists"].tap()
        app.buttons[String(name)].tap()
        XCTAssertTrue(app.staticTexts["Tracks · 3"].waitForExistence(timeout: 5))
    }
}
