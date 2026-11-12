import XCTest
import SwiftData
import AVFoundation
@testable import Soundly

@MainActor
final class LibraryIntegrationTests: XCTestCase {
    private func container(_ url: URL? = nil) throws -> ModelContainer {
        let configuration:ModelConfiguration
        if let url { configuration = ModelConfiguration(url:url,cloudKitDatabase:.none) }
        else { configuration = ModelConfiguration(isStoredInMemoryOnly:true,cloudKitDatabase:.none) }
        return try ModelContainer(for:Song.self,configurations:configuration)
    }
    private func fixture(_ root:URL) throws -> URL {
        let url = root.appendingPathComponent("音楽 — Prueba.wav")
        let format = try XCTUnwrap(AVAudioFormat(commonFormat:.pcmFormatInt16,sampleRate:44100,channels:2,interleaved:true))
        let file = try AVAudioFile(forWriting:url,settings:format.settings,commonFormat:.pcmFormatInt16,interleaved:true)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat:format,frameCapacity:1024))
        buffer.frameLength = 1024
        let ptr = try XCTUnwrap(buffer.int16ChannelData)[0]
        for i in 0..<2048 { ptr[i] = Int16(i % 1000) }
        try file.write(from:buffer)
        return url
    }
    func testActualWAVImportDuplicateDetectionAndMetadata() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let url = try fixture(root)
        let db = try container()
        let importer = await Task.detached { MusicImporter(writer:LibraryWriter(modelContainer:db)) }.value
        let result = await importer.run([url,url]) { _ in }
        XCTAssertEqual(result.imported,1); XCTAssertEqual(result.duplicates,1); XCTAssertEqual(result.failures,0)
        let songs = try db.mainContext.fetch(FetchDescriptor<Song>())
        let song = try XCTUnwrap(songs.first)
        XCTAssertEqual(song.title,"音楽 — Prueba")
        XCTAssertEqual(song.sampleRate,44100); XCTAssertEqual(song.bitDepth,16); XCTAssertEqual(song.channels,2)
        XCTAssertEqual(song.codec,"PCM")
        XCTAssertTrue(FileManager.default.fileExists(atPath:try LibraryPaths.directory("Music").appendingPathComponent(song.filename).path))
        XCTAssertEqual(song.hash.count,64)
    }
    func testCorruptFileDoesNotCreateLibraryRow() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".flac")
        try Data("not audio".utf8).write(to:url); defer { try? FileManager.default.removeItem(at:url) }
        let db = try container()
        let importer = await Task.detached { MusicImporter(writer:LibraryWriter(modelContainer:db)) }.value
        let result = await importer.run([url]) { _ in }
        XCTAssertEqual(result.failures,1); XCTAssertEqual(result.imported,0)
        XCTAssertEqual(try db.mainContext.fetchCount(FetchDescriptor<Song>()),0)
    }
    func testCancelledTaskDoesNotImport() async throws {
        let db = try container()
        let importer = await Task.detached { MusicImporter(writer:LibraryWriter(modelContainer:db)) }.value
        let task = Task { () -> ImportProgress in
            withUnsafeCurrentTask { $0?.cancel() }
            return await importer.run([URL(fileURLWithPath:"/unavailable.wav")]) { _ in }
        }
        let result = await task.value
        XCTAssertTrue(result.cancelled); XCTAssertEqual(result.imported,0)
    }
    func testPersistenceAfterReopeningAndMissingFileRescanPreservesRecord() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let url = root.appendingPathComponent("test.store")
        do {
            let db = try container(url)
            let item = ImportedSong(hash:UUID().uuidString,filename:UUID().uuidString+".wav",metadata:MusicMetadata(title:"Persistent"),size:5,artwork:nil,folder:"Test")
            db.mainContext.insert(Song(item)); try db.mainContext.save()
        }
        let reopened = try container(url)
        XCTAssertEqual(try reopened.mainContext.fetchCount(FetchDescriptor<Song>()),1)
        let writer = await Task.detached { LibraryWriter(modelContainer:reopened) }.value
        let missing = try await writer.rescan()
        XCTAssertEqual(missing,1)
        let check = try container(url)
        let song = try XCTUnwrap(check.mainContext.fetch(FetchDescriptor<Song>()).first)
        XCTAssertFalse(song.available); XCTAssertEqual(song.title,"Persistent")
    }
    func testNestedFolderImportSkipsSymlinkAndUnsupportedFile() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sub = root.appendingPathComponent("Album")
        try FileManager.default.createDirectory(at:sub,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let audio = try fixture(sub)
        try FileManager.default.createSymbolicLink(at:root.appendingPathComponent("link.wav"),withDestinationURL:audio)
        try Data("readme".utf8).write(to:root.appendingPathComponent("readme.txt"))
        let db = try container()
        let importer = await Task.detached { MusicImporter(writer:LibraryWriter(modelContainer:db)) }.value
        let result = await importer.run([root]) { _ in }
        XCTAssertEqual(result.imported,1); XCTAssertEqual(result.discovered,1)
    }
    func testFLACParserRejectsTruncatedBlock() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:url) }
        try Data(Array("fLaC".utf8)+[0x80,0,0,34,0]).write(to:url)
        var metadata = MusicMetadata()
        XCTAssertThrowsError(try FLACMetadata.read(url,into:&metadata))
    }
}
