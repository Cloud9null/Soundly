import XCTest
@testable import SoundlyCore

final class MetadataTests: XCTestCase {
    func testInvalidPCMMeasurementsAreRejected() {
        for rate in [0.0, -1, .nan, .infinity] {
            XCTAssertThrowsError(try PCMFormat(sampleRate: rate, channels: 2,
                                              bitDepth: 24, representation: .signedInteger))
        }
        XCTAssertThrowsError(try PCMFormat(sampleRate: 44_100, channels: 0,
                                          bitDepth: 16, representation: .signedInteger))
        XCTAssertThrowsError(try PCMFormat(sampleRate: 44_100, channels: 2,
                                          bitDepth: 0, representation: .signedInteger))
    }

    func testImportedPathCannotEscapePrivateMusicDirectory() {
        for filename in ["", ".", "..", "../song.flac", "/song.flac", "folder/song.flac", "folder\\song.flac", "song\0.flac"] {
            XCTAssertThrowsError(try Track(fileSHA256: String(repeating: "a", count: 64),
                                           internalFilename: filename, title: "Music", fileSize: 1))
        }
    }

    func testUnicodeAndMissingMetadataArePreserved() throws {
        let track = try Track(fileSHA256: String(repeating: "f", count: 64),
                              internalFilename: "Björk-音楽.flac", title: "أغنية — 音楽 🎵", fileSize: 12)
        XCTAssertEqual(track.title, "أغنية — 音楽 🎵")
        XCTAssertNil(track.sourcePCM)
        XCTAssertNil(track.isLossless)
        XCTAssertNil(track.artist)
        XCTAssertEqual(track.playCount, 0)
    }

    func testMalformedContentHashAndNegativeSizeAreRejected() {
        XCTAssertThrowsError(try Track(fileSHA256: "not-a-hash", internalFilename: "a.flac",
                                       title: "Music", fileSize: 1))
        XCTAssertThrowsError(try Track(fileSHA256: String(repeating: "z", count: 64), internalFilename: "a.flac",
                                       title: "Music", fileSize: 1))
        XCTAssertThrowsError(try Track(fileSHA256: String(repeating: "a", count: 64), internalFilename: "a.flac",
                                       title: "Music", fileSize: -1))
    }
}
