import XCTest

@MainActor final class ExpansionUITests:XCTestCase {
    func testSmartQueueAndOfflineLyricsMenu() {
        let app = XCUIApplication();app.launchArguments = ["--soundly-fixtures"];app.launch()
        XCTAssertTrue(app.navigationBars["Listen"].waitForExistence(timeout:30))
        app.tabBars.buttons["Library"].tap();app.buttons["libraryBrowse"].tap();app.buttons["Smart Playlists"].tap()
        XCTAssertTrue(app.navigationBars["Smart Playlists"].waitForExistence(timeout:5))
        let rule = app.buttons["smartRule-Never played"];XCTAssertTrue(rule.waitForExistence(timeout:5));rule.tap()
        XCTAssertTrue(app.navigationBars["Never played"].waitForExistence(timeout:5))
        app.staticTexts["Reference 1"].firstMatch.tap()
        let miniPlayer = app.buttons["miniPlayerOpen"];XCTAssertTrue(miniPlayer.waitForExistence(timeout:10))
        var openPoint:CGPoint?
        let selected = NSPredicate { _,_ in
            guard miniPlayer.exists,miniPlayer.isHittable,(miniPlayer.value as? String)?.hasPrefix("Reference 1") == true else { return false }
            let frame = miniPlayer.frame;let window = app.frame
            guard frame.minX.isFinite,frame.minY.isFinite,frame.width.isFinite,frame.height.isFinite,
                  frame.width >= 44,frame.height >= 44,window.contains(frame) else { return false }
            openPoint = CGPoint(x:frame.minX+frame.width*0.2-window.minX,y:frame.midY-window.minY)
            return true
        }
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:selected,object:miniPlayer)],timeout:20),.completed)
        guard let openPoint else { return }
        // Anchor to the stable app window: the native accessory can return a transient infinite AX frame.
        app.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:openPoint.x,dy:openPoint.y)).tap()
        XCTAssertTrue(app.buttons["playbackMenu"].waitForExistence(timeout:10))
        app.buttons["playbackMenu"].tap()
        let identifiedLyrics = app.buttons["openLyrics"]
        let lyrics = identifiedLyrics.waitForExistence(timeout:2) ? identifiedLyrics : app.buttons["Lyrics"]
        XCTAssertTrue(lyrics.waitForExistence(timeout:5))
        var lyricsPoint:CGPoint?
        let menuSettled = NSPredicate { _,_ in
            guard lyrics.exists else { return false }
            let frame = lyrics.frame;let window = app.frame
            guard frame.minX.isFinite,frame.minY.isFinite,frame.width.isFinite,frame.height.isFinite,
                  frame.width > 0,frame.height > 0,window.contains(frame) else { return false }
            lyricsPoint = CGPoint(x:frame.midX-window.minX,y:frame.midY-window.minY);return true
        }
        XCTAssertEqual(XCTWaiter.wait(for:[XCTNSPredicateExpectation(predicate:menuSettled,object:lyrics)],timeout:10),.completed)
        guard let lyricsPoint else { return }
        app.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:lyricsPoint.x,dy:lyricsPoint.y)).tap()
        XCTAssertTrue(app.navigationBars["Lyrics"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts["Your words, offline"].waitForExistence(timeout:5))
        let shot = XCTAttachment(screenshot:app.screenshot());shot.name = "Offline lyrics empty state";shot.lifetime = .keepAlways;add(shot)
    }
    func testPlaylistCreationTrackSelectionAndPersistence() {
        let app = XCUIApplication(); app.launchArguments = ["--soundly-fixtures"]; app.launch()
        XCTAssertTrue(app.navigationBars["Listen"].waitForExistence(timeout:30))
        app.tabBars.buttons["Library"].tap(); app.buttons["libraryBrowse"].tap(); app.buttons["Playlists"].tap()
        let name = "Travel-"+String(UUID().uuidString.prefix(6))
        app.textFields["playlistName"].tap(); app.textFields["playlistName"].typeText(String(name))
        app.buttons["createPlaylist"].tap(); app.buttons[String(name)].tap()
        XCTAssertTrue(app.navigationBars[String(name)].waitForExistence(timeout:5))
        XCTAssertTrue(app.buttons["Export M3U8"].exists)
        app.buttons["Add songs"].tap()
        XCTAssertTrue(app.navigationBars["Add songs"].waitForExistence(timeout: 5))
        app.buttons.containing(NSPredicate(format:"label CONTAINS %@","Reference 1")).firstMatch.tap()
        app.buttons["addSelectedSongs"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format:"label CONTAINS[c] %@","Tracks · 1")).firstMatch.exists)
        app.terminate(); app.launch(); XCTAssertTrue(app.navigationBars["Listen"].waitForExistence(timeout:30))
        app.tabBars.buttons["Library"].tap(); app.buttons["libraryBrowse"].tap(); app.buttons["Playlists"].tap()
        XCTAssertTrue(app.buttons[String(name)].waitForExistence(timeout:5))
    }
}
