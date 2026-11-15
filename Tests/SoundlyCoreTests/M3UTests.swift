import XCTest
@testable import SoundlyCore

final class M3UTests:XCTestCase {
    private let hash = String(repeating:"a",count:64)
    func testUnicodeWindowsPathsAndEXTINF() throws {
        let source = "\u{feff}#EXTM3U\r\n#EXTINF:123,Artista - Corazón 世界\r\nC:\\Music\\Corazón 世界.flac\r\n"
        let result = try M3U.parse(Data(source.utf8))
        XCTAssertEqual(result.entries,[M3UEntry(reference:"Corazón 世界.flac",title:"Artista - Corazón 世界",duration:123)])
        XCTAssertEqual(result.remoteCount,0)
    }
    func testRemoteReferencesAndTraversalNeverBecomeAccessGrants() throws {
        let source = "https://example.invalid/song.flac\nfile://server/private/track.flac\n\\\\server\\music\\song.flac\n../../safe.flac\n..\nname%2Fescape.flac\nfile:///tmp/safe%20song.flac"
        let value = try M3U.parse(Data(source.utf8))
        XCTAssertEqual(value.remoteCount,3);XCTAssertEqual(value.invalidCount,2)
        XCTAssertEqual(value.entries.map(\.reference),["safe.flac","safe song.flac"])
    }
    func testHashRoundtripAndOrderedDeduplication() throws {
        let entry = M3UEntry(reference:hash+".flac",title:"Artist - Song",duration:60,sha256:hash)
        let parsed = try M3U.parse(M3U.encode([entry,entry]))
        XCTAssertEqual(parsed.entries,[entry,entry])
        let result = M3U.resolve(parsed.entries,catalog:[M3UCatalogItem(hash:hash,filename:hash+".flac",title:"Song",artist:"Artist")])
        XCTAssertEqual(result.hashes,[hash]);XCTAssertEqual(result.duplicateCount,1)
    }
    func testAmbiguousMetadataAndUnknownHashesStayUnresolved() {
        let second = String(repeating:"b",count:64)
        let catalog = [M3UCatalogItem(hash:hash,filename:hash+".flac",title:"Song",artist:"Artist"),M3UCatalogItem(hash:second,filename:second+".flac",title:"Song",artist:"Artist")]
        let ambiguous = M3UEntry(reference:"Song.flac",title:"Artist - Song")
        let unknown = M3UEntry(reference:hash+".flac",title:"Artist - Song",sha256:String(repeating:"c",count:64))
        let result = M3U.resolve([ambiguous,unknown],catalog:catalog)
        XCTAssertTrue(result.hashes.isEmpty);XCTAssertEqual(result.unresolved,[ambiguous,unknown]);XCTAssertEqual(result.ambiguousCount,1)
    }
    func testUniqueMetadataFallbackRetainsTrackOrder() {
        let result = M3U.resolve([M3UEntry(reference:"Other.flac"),M3UEntry(reference:"01 song.flac",title:"Artist - Song")],catalog:[M3UCatalogItem(hash:"one",filename:"x.flac",title:"Song",artist:"Artist"),M3UCatalogItem(hash:"two",filename:"y.flac",title:"Other",artist:"Someone")])
        XCTAssertEqual(result.hashes,["two","one"])
    }
    func testStreamingListsMalformedHashesAndEncodingAreRejected() {
        XCTAssertThrowsError(try M3U.parse(Data("#EXTM3U\n#EXT-X-TARGETDURATION:6\nsegment.ts".utf8)))
        XCTAssertThrowsError(try M3U.parse(Data("#SOUNDLY-SHA256:bad\ntrack.flac".utf8)))
        XCTAssertThrowsError(try M3U.parse(Data([0xff,0xff])))
        XCTAssertNoThrow(try M3U.parse(Data([0xE9,0x2e,0x66,0x6c,0x61,0x63]),strictUTF8:false))
    }
    func testExportDoesNotInjectLinesOrAbsolutePaths() throws {
        XCTAssertThrowsError(try M3U.encode([M3UEntry(reference:"../track.flac")]))
        XCTAssertThrowsError(try M3U.encode([M3UEntry(reference:"a\nb.flac")]))
        let data = try M3U.encode([M3UEntry(reference:"track.flac",title:"Song\n#EXT-X-BAD")])
        let parsed = try M3U.parse(data)
        XCTAssertEqual(parsed.entries.count,1);XCTAssertEqual(parsed.entries[0].title,"Song #EXT-X-BAD")
    }
    func testResourceBounds() {
        XCTAssertThrowsError(try M3U.parse(Data(repeating:65,count:M3U.byteLimit+1)))
        XCTAssertThrowsError(try M3U.parse(Data(String(repeating:"a.flac\n",count:20001).utf8)))
    }
}
