import XCTest
@testable import Soundly

final class LibraryExpansionTests:XCTestCase {
    func testLyricsPersistenceRejectsBadReplacementAndTraversal() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:folder) }
        let store = LyricsStore(directory:folder)
        _ = try await store.write("track",data:Data("[00:01]Hello".utf8),synchronized:true)
        do { _ = try await store.write("track",data:Data([0xff,0xff]),synchronized:false); XCTFail("Invalid UTF-8 accepted") } catch {}
        let reopened = LyricsStore(directory:folder)
        let doc = try await reopened.read("track");XCTAssertEqual(doc?.cue(at:2)?.text,"Hello")
        do { _ = try await store.read("../escape");XCTFail("Path escape accepted") } catch {}
        try await store.remove("track");let removed = try await store.read("track");XCTAssertNil(removed)
    }
    @MainActor func testSmartRulesReflectActualMetadataAndPlayStarts() {
        let song = Song(ImportedSong(hash:"smart",filename:"smart.wav",metadata:MusicMetadata(title:"Smart",artist:"Artist",album:"Album"),size:100,artwork:nil,folder:"Test"))
        XCTAssertTrue(SmartRule.neverPlayed.matches(song));XCTAssertFalse(SmartRule.mostPlayed.matches(song))
        song.playCount = 4;song.favorite = true;song.codec = "FLAC";song.bitDepth = 24
        XCTAssertTrue(SmartRule.mostPlayed.matches(song));XCTAssertTrue(SmartRule.favorites.matches(song));XCTAssertTrue(SmartRule.flac.matches(song));XCTAssertTrue(SmartRule.hiRes.matches(song))
        song.bitDepth = 16;song.sampleRate = 44100;XCTAssertFalse(SmartRule.hiRes.matches(song))
        let now = Date();song.dateAdded = now.addingTimeInterval(-31*86400);XCTAssertFalse(SmartRule.recent.matches(song,now:now))
    }
}
