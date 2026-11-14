import XCTest
import AVFoundation
@testable import Soundly

final class ExpansionTests:XCTestCase {
    func testIntegrityOverridesEQAndMalformedGainsAreClamped() {
        var value = AudioSettings(); value.equalizer = true; value.gains = [6]
        XCTAssertFalse(value.processing)
        value.integrity = false; XCTAssertTrue(value.validated.processing)
        value.gains = [.nan,100,-100]; XCTAssertEqual(value.validated.gains,[0,6,-12,0,0])
    }
    func testPlaylistRoundtripPreservesOrderAndRejectsInvalidExchange() throws {
        let first = LocalPlaylist(name:"Travel",hashes:["b","a"])
        let bytes = try JSONEncoder().encode(PlaylistExchange(playlists:[first,LocalPlaylist(name:"Home")]))
        XCTAssertEqual(try PlaylistExchange.decode(bytes).playlists,[first,LocalPlaylist(id:try PlaylistExchange.decode(bytes).playlists[1].id,name:"Home")])
        let invalid = try JSONEncoder().encode(PlaylistExchange(playlists:[LocalPlaylist(name:"",hashes:[])]))
        XCTAssertThrowsError(try PlaylistExchange.decode(invalid))
    }
    func testSourceEnvelopeUsesActualDecodedSamples() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".wav")
        defer { try? FileManager.default.removeItem(at:url) }
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate:44100,channels:1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat:format,frameCapacity:256)); buffer.frameLength = 256
        for i in 0..<256 { buffer.floatChannelData![0][i] = i < 128 ? 0 : 0.5 }
        do { let file = try AVAudioFile(forWriting:url,settings:format.settings); try file.write(from:buffer) }
        let values = try SourceEnvelope.analyze(url)
        XCTAssertEqual(values.count,256); XCTAssertEqual(values.first,0); XCTAssertEqual(values.last,0.5)
    }
}
