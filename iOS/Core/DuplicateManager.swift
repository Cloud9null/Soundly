import Foundation
import SwiftData
import CryptoKit

struct DuplicateEntry:Identifiable,Sendable {
    let id:UUID
    let filename:String
    let title:String
    let artist:String
    let dateAdded:Date
    let bytes:Int64
}
struct DuplicateGroup:Identifiable,Sendable {
    let id:String // SHA-256 of actual file bytes, never an audio-output verification hash.
    let entries:[DuplicateEntry]
    var extraCount:Int { max(0,entries.count-1) }
}
struct DuplicateReport:Sendable {
    var groups:[DuplicateGroup] = []
    var checked = 0
    var skipped = 0
    var pendingRecovery = 0
    var extraCount:Int { groups.reduce(0) { $0+$1.extraCount } }
}
struct DuplicateScanProgress:Sendable { let checked:Int; let total:Int }
struct DuplicateRemoval:Sendable {
    let removedIDs:Set<UUID>
    let reclaimedBytes:Int64
    let cleanupPending:Bool
}
struct DuplicateJournal:Codable {
    struct Entry:Codable { let id:UUID; let filename:String; let stagedName:String }
    let entries:[Entry]
}

enum PrivateMusicFile {
    static func url(_ filename:String,in directory:URL)throws->URL {
        guard !filename.isEmpty,filename == URL(fileURLWithPath:filename).lastPathComponent,
              !filename.contains("\\"),!filename.contains("\0"),filename != ".",filename != ".." else { throw CocoaError(.fileReadInvalidFileName) }
        return directory.appendingPathComponent(filename)
    }
    static func hash(_ url:URL)throws->(String,Int64) {
        let info = try url.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey,.fileSizeKey])
        guard info.isRegularFile == true, info.isSymbolicLink != true else { throw CocoaError(.fileReadInvalidFileName) }
        let handle = try FileHandle(forReadingFrom:url); defer { try? handle.close() }
        var digest = SHA256(); var bytes:Int64 = 0
        while true {
            try Task.checkCancellation()
            let chunk = try handle.read(upToCount:1024*1024) ?? Data()
            if chunk.isEmpty { break }
            digest.update(data:chunk); bytes += Int64(chunk.count)
        }
        return (digest.finalize().map { String(format:"%02x",$0) }.joined(),bytes)
    }
}

/// Background file hashing and journalled removal of extra private copies only.
@ModelActor actor DuplicateManager {
    func scan(base:URL? = nil,progress:@Sendable (DuplicateScanProgress)->Void = { _ in })throws->DuplicateReport {
        let root = try base ?? LibraryPaths.base()
        let pending = try recoverPendingRemovals(base:root)
        let music = root.appendingPathComponent("Music",isDirectory:true)
        let songs = try modelContext.fetch(FetchDescriptor<Song>())
        var report = DuplicateReport(); report.pendingRecovery = pending
        var buckets:[String:[DuplicateEntry]] = [:]
        for song in songs {
            try Task.checkCancellation()
            do {
                let (hash,bytes) = try PrivateMusicFile.hash(PrivateMusicFile.url(song.filename,in:music))
                buckets[hash,default:[]].append(DuplicateEntry(id:song.id,filename:song.filename,title:song.title,artist:song.artist,dateAdded:song.dateAdded,bytes:bytes))
            } catch is CancellationError { throw CancellationError() }
            catch { report.skipped += 1 }
            report.checked += 1; progress(DuplicateScanProgress(checked:report.checked,total:songs.count))
        }
        report.groups = buckets.compactMap { hash,entries in
            guard entries.count > 1 else { return nil }
            let ordered = entries.sorted { $0.dateAdded == $1.dateAdded ? $0.id.uuidString < $1.id.uuidString : $0.dateAdded < $1.dateAdded }
            return DuplicateGroup(id:hash,entries:ordered)
        }.sorted { ($0.entries.first?.title ?? "") < ($1.entries.first?.title ?? "") }
        return report
    }

    func removeExtras(_ report:DuplicateReport,preferKeeping:UUID?,base:URL? = nil)throws->DuplicateRemoval {
        let root = try base ?? LibraryPaths.base()
        guard try recoverPendingRemovals(base:root) == 0 else { throw failure("A previous cleanup has preserved recovery files. No new copies were removed.") }
        let music = root.appendingPathComponent("Music",isDirectory:true)
        let songs = try modelContext.fetch(FetchDescriptor<Song>())
        let byID = Dictionary(uniqueKeysWithValues:songs.map { ($0.id,$0) })
        var removed:Set<UUID> = []
        var plans:[(keeper:Song,extras:[Song])] = []
        // Re-hash every retained/deleted candidate before any mutation; cached library hashes are insufficient.
        for group in report.groups {
            try Task.checkCancellation()
            var candidates:[Song] = []
            for entry in group.entries {
                guard let song = byID[entry.id],song.filename == entry.filename else { throw failure("The library changed. Scan again before removing copies.") }
                let (digest,_) = try PrivateMusicFile.hash(PrivateMusicFile.url(song.filename,in:music))
                guard digest == group.id else { throw failure("A candidate file changed. All copies were preserved; scan again.") }
                candidates.append(song)
            }
            guard candidates.count > 1 else { continue }
            let keeper = candidates.first { $0.id == preferKeeping } ?? candidates[0]
            let extras = candidates.filter { $0.id != keeper.id }
            removed.formUnion(extras.map(\.id)); plans.append((keeper,extras))
        }
        if removed.isEmpty { return DuplicateRemoval(removedIDs:[],reclaimedBytes:0,cleanupPending:false) }
        let retainedNames = Set(songs.filter { !removed.contains($0.id) }.map(\.filename))
        var stagedNames:Set<String> = []
        var journalEntries:[DuplicateJournal.Entry] = []
        for song in songs where removed.contains(song.id) && !retainedNames.contains(song.filename) {
            if stagedNames.insert(song.filename).inserted {
                journalEntries.append(.init(id:song.id,filename:song.filename,stagedName:UUID().uuidString))
            }
        }
        let recovery = root.appendingPathComponent("DuplicateRecovery",isDirectory:true).appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:recovery,withIntermediateDirectories:true)
        let journal = recovery.appendingPathComponent("journal.json")
        try JSONEncoder().encode(DuplicateJournal(entries:journalEntries)).write(to:journal,options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication])
        var bytes:Int64 = 0
        do {
            // Once moves begin, finish/rollback this transaction even if the UI task was cancelled.
            for entry in journalEntries {
                let source = try PrivateMusicFile.url(entry.filename,in:music)
                let size = (try FileManager.default.attributesOfItem(atPath:source.path)[.size] as? NSNumber)?.int64Value ?? 0
                try FileManager.default.moveItem(at:source,to:PrivateMusicFile.url(entry.stagedName,in:recovery)); bytes += size
            }
            for (keeper,extras) in plans {
                keeper.favorite = keeper.favorite || extras.contains { $0.favorite }
                for song in extras {
                    let (sum,overflow) = keeper.playCount.addingReportingOverflow(song.playCount)
                    keeper.playCount = overflow ? Int.max : sum
                    if let date = song.lastPlayed,keeper.lastPlayed.map({date > $0}) ?? true { keeper.lastPlayed = date }
                    modelContext.delete(song)
                }
            }
            try modelContext.save()
        } catch {
            modelContext.rollback()
            _ = try? recoverPendingRemovals(base:root)
            throw failure("Cleanup could not finish. Records were rolled back and recovery copies were preserved.")
        }
        do {
            try FileManager.default.removeItem(at:recovery)
            return DuplicateRemoval(removedIDs:removed,reclaimedBytes:bytes,cleanupPending:false)
        } catch { return DuplicateRemoval(removedIDs:removed,reclaimedBytes:0,cleanupPending:true) }
    }

    /// Called at startup and before maintenance. Incomplete moves are restored; committed deletes finish cleanup.
    @discardableResult func recoverPendingRemovals(base:URL? = nil)throws->Int {
        let root = try base ?? LibraryPaths.base()
        let directory = root.appendingPathComponent("DuplicateRecovery",isDirectory:true)
        guard FileManager.default.fileExists(atPath:directory.path) else { return 0 }
        let music = root.appendingPathComponent("Music",isDirectory:true)
        let songs = try modelContext.fetch(FetchDescriptor<Song>())
        var pending = 0
        for folder in try FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:[.isDirectoryKey,.isSymbolicLinkKey],options:.skipsHiddenFiles) {
            let info = try folder.resourceValues(forKeys:[.isDirectoryKey,.isSymbolicLinkKey])
            guard info.isDirectory == true,info.isSymbolicLink != true else { continue }
            let journalURL = folder.appendingPathComponent("journal.json")
            guard FileManager.default.fileExists(atPath:journalURL.path) else { continue }
            let handle = try FileHandle(forReadingFrom:journalURL)
            let bytes = try handle.read(upToCount:8*1024*1024+1) ?? Data(); try handle.close()
            guard bytes.count <= 8*1024*1024 else { throw failure("A cleanup recovery record is invalid. Files were preserved.") }
            let journal = try JSONDecoder().decode(DuplicateJournal.self,from:bytes)
            var unresolved = false
            for entry in journal.entries {
                let source = try PrivateMusicFile.url(entry.stagedName,in:folder)
                let destination = try PrivateMusicFile.url(entry.filename,in:music)
                guard FileManager.default.fileExists(atPath:source.path) else { continue }
                if songs.contains(where:{ $0.id == entry.id && $0.filename == entry.filename }) {
                    if !FileManager.default.fileExists(atPath:destination.path) { try FileManager.default.moveItem(at:source,to:destination) }
                    else if try PrivateMusicFile.hash(source).0 == PrivateMusicFile.hash(destination).0 { try FileManager.default.removeItem(at:source) }
                    else { unresolved = true; pending += 1 } // Never overwrite a different restored file.
                } else { try FileManager.default.removeItem(at:source) }
            }
            if !unresolved { try FileManager.default.removeItem(at:folder) }
        }
        return pending
    }
    private func failure(_ message:String)->NSError { NSError(domain:"Soundly.Library",code:1,userInfo:[NSLocalizedDescriptionKey:message]) }
}
