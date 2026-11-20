import XCTest
@testable import SoundlyCore

final class LyricsTests:XCTestCase {
    func testMultipleTimestampsFractionsAndUnicode() throws {
        let doc = try LyricsDocument.parse("[ar:Artist]\n[00:01.2][00:02.345]Corazón 世界",synchronized:true)
        XCTAssertEqual(doc.cues.map(\.time),[1.2,2.345]);XCTAssertEqual(doc.cues.first?.text,"Corazón 世界")
    }
    func testOffsetSortAndEqualTimestampTranslation() throws {
        let doc = try LyricsDocument.parse("[00:02]two\n[offset:-1000]\n[00:01]one\n[00:01]uno",synchronized:true)
        XCTAssertEqual(doc.cues.map(\.time),[0,1]);XCTAssertEqual(doc.cues[0].text,"one\nuno")
    }
    func testCueBoundariesAndInvalidClock() throws {
        let doc = try LyricsDocument.parse("[00:02]two\n[00:05]five",synchronized:true)
        XCTAssertNil(doc.cue(at:1.9));XCTAssertEqual(doc.cue(at:2)?.text,"two");XCTAssertEqual(doc.cue(at:500)?.text,"five");XCTAssertNil(doc.cue(at:.nan))
    }
    func testPlainTextPreservesHeadingsAndLineBreaks() throws {
        let doc = try LyricsDocument.parse("[Chorus]\r\nHello",synchronized:false)
        XCTAssertEqual(doc.text,"[Chorus]\nHello");XCTAssertTrue(doc.cues.isEmpty)
    }
    func testMalformedTimestampsDoNotInventCues() throws {
        let doc = try LyricsDocument.parse("[00:99]invalid\nWords",synchronized:true)
        XCTAssertTrue(doc.cues.isEmpty);XCTAssertTrue(doc.text.contains("invalid"))
    }
    func testOversizedTextIsRejected() {
        XCTAssertThrowsError(try LyricsDocument.parse(String(repeating:"x",count:1_048_577),synchronized:true))
    }
}
