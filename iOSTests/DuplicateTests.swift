import XCTest
import SwiftData
@testable import Soundly

@MainActor final class DuplicateTests:XCTestCase {
    private func fixture(sharedName:Bool = false)throws->(ModelContainer,URL,[UUID]) {
        let db = try ModelContainer(for:Song.self,configurations:ModelConfiguration(isStoredInMemoryOnly:true,cloudKitDatabase:.none))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let music = root.appendingPathComponent("Music")
        try FileManager.default.createDirectory(at:music,withIntermediateDirectories:true)
        var ids:[UUID] = []
        for i in 0..<3 {
            let name = sharedName && i == 1 ? "0.wav" : "\(i).wav"
            let bytes = Data((i < 2 ? "identical reference bytes" : "different reference bytes").utf8)
            try bytes.write(to:music.appendingPathComponent(name))
            let item = ImportedSong(hash:"legacy-\(i)",filename:name,metadata:MusicMetadata(title:"Reference \(i)"),size:Int64(bytes.count),artwork:nil,folder:"Original source untouched")
            let song = Song(item); song.dateAdded = Date(timeIntervalSince1970:Double(i)); song.favorite = i == 1; song.playCount = i+1
            song.lastPlayed = Date(timeIntervalSince1970:Double(i+10)); db.mainContext.insert(song); ids.append(song.id)
        }
        try db.mainContext.save(); return (db,root,ids)
    }
    private func worker(_ db:ModelContainer)async->DuplicateManager { await Task.detached { DuplicateManager(modelContainer:db) }.value }
    func testActualHashScanAndRemovalMergeHistoryKeepPreferred() async throws {
        let (db,root,ids) = try fixture(); defer { try? FileManager.default.removeItem(at:root) }
        let manager = await worker(db)
        let report = try await manager.scan(base:root)
        XCTAssertEqual(report.groups.count,1); XCTAssertEqual(report.extraCount,1); XCTAssertEqual(report.checked,3)
        let result = try await manager.removeExtras(report,preferKeeping:ids[1],base:root)
        XCTAssertEqual(result.removedIDs,[ids[0]]); XCTAssertGreaterThan(result.reclaimedBytes,0)
        let context = ModelContext(db)
        let rows = try context.fetch(FetchDescriptor<Song>())
        XCTAssertEqual(rows.count,2)
        let kept = try XCTUnwrap(rows.first { $0.id == ids[1] })
        XCTAssertTrue(kept.favorite); XCTAssertEqual(kept.playCount,3)
        XCTAssertTrue(FileManager.default.fileExists(atPath:root.appendingPathComponent("Music/1.wav").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath:root.appendingPathComponent("Music/0.wav").path))
    }
    func testChangedCandidateAbortsBeforeDeletion() async throws {
        let (db,root,_) = try fixture(); defer { try? FileManager.default.removeItem(at:root) }
        let manager = await worker(db); let report = try await manager.scan(base:root)
        try Data("changed after scan".utf8).write(to:root.appendingPathComponent("Music/1.wav"))
        do { _ = try await manager.removeExtras(report,preferKeeping:nil,base:root); XCTFail("Changed file was removed") } catch {}
        XCTAssertEqual(try ModelContext(db).fetchCount(FetchDescriptor<Song>()),3)
        XCTAssertTrue(FileManager.default.fileExists(atPath:root.appendingPathComponent("Music/0.wav").path))
    }
    func testSharedPrivatePathDoesNotDeleteRetainedFile() async throws {
        let (db,root,_) = try fixture(sharedName:true); defer { try? FileManager.default.removeItem(at:root) }
        let manager = await worker(db); let report = try await manager.scan(base:root)
        let result = try await manager.removeExtras(report,preferKeeping:nil,base:root)
        XCTAssertEqual(result.removedIDs.count,1); XCTAssertEqual(result.reclaimedBytes,0)
        XCTAssertTrue(FileManager.default.fileExists(atPath:root.appendingPathComponent("Music/0.wav").path))
    }
    func testMissingFilesAreSkippedAndScanCancellationDoesNotMutate() async throws {
        let (db,root,_) = try fixture(); defer { try? FileManager.default.removeItem(at:root) }
        try FileManager.default.removeItem(at:root.appendingPathComponent("Music/2.wav"))
        let manager = await worker(db); let report = try await manager.scan(base:root)
        XCTAssertEqual(report.skipped,1); XCTAssertEqual(report.extraCount,1)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await manager.scan(base:root)
        }
        do { _ = try await task.value; XCTFail("Cancelled scan completed") } catch is CancellationError {} catch { XCTFail("Unexpected cancellation error") }
        XCTAssertEqual(try ModelContext(db).fetchCount(FetchDescriptor<Song>()),3)
    }
    func testCrashRecoveryRestoresUncommittedMove() async throws {
        let (db,root,ids) = try fixture(); defer { try? FileManager.default.removeItem(at:root) }
        let folder = root.appendingPathComponent("DuplicateRecovery/operation")
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        try FileManager.default.moveItem(at:root.appendingPathComponent("Music/0.wav"),to:folder.appendingPathComponent("staged"))
        let journal = DuplicateJournal(entries:[.init(id:ids[0],filename:"0.wav",stagedName:"staged")])
        try JSONEncoder().encode(journal).write(to:folder.appendingPathComponent("journal.json"))
        let manager = await worker(db); let pending = try await manager.recoverPendingRemovals(base:root)
        XCTAssertEqual(pending,0); XCTAssertTrue(FileManager.default.fileExists(atPath:root.appendingPathComponent("Music/0.wav").path))
        XCTAssertEqual(try ModelContext(db).fetchCount(FetchDescriptor<Song>()),3)
    }
    func testCrashRecoveryFinishesCommittedDelete() async throws {
        let (db,root,ids) = try fixture(); defer { try? FileManager.default.removeItem(at:root) }
        let folder = root.appendingPathComponent("DuplicateRecovery/operation")
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        try FileManager.default.moveItem(at:root.appendingPathComponent("Music/0.wav"),to:folder.appendingPathComponent("staged"))
        try JSONEncoder().encode(DuplicateJournal(entries:[.init(id:ids[0],filename:"0.wav",stagedName:"staged")])).write(to:folder.appendingPathComponent("journal.json"))
        let song = try XCTUnwrap(db.mainContext.fetch(FetchDescriptor<Song>()).first { $0.id == ids[0] }); db.mainContext.delete(song); try db.mainContext.save()
        let manager = await worker(db); let pending = try await manager.recoverPendingRemovals(base:root)
        XCTAssertEqual(pending,0); XCTAssertFalse(FileManager.default.fileExists(atPath:folder.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath:root.appendingPathComponent("Music/1.wav").path))
    }
    func testTraversalAndSymbolicLinksAreNotHashed() throws {
        let (_,root,_) = try fixture(); defer { try? FileManager.default.removeItem(at:root) }
        for name in ["../outside","/outside","nested/path","nested\\path","", ".", ".."] {
            XCTAssertThrowsError(try PrivateMusicFile.url(name,in:root))
        }
        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at:link,withDestinationURL:root.appendingPathComponent("Music/0.wav"))
        XCTAssertThrowsError(try PrivateMusicFile.hash(link))
    }
}
