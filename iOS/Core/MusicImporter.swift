import Foundation
import CryptoKit
import SwiftData
import Observation

struct ImportProgress: Sendable {
    var discovered = 0
    var processed = 0
    var imported = 0
    var duplicates = 0
    var restored = 0
    var failures = 0
    var scanning = true
    var cancelled = false
    var issues: [String] = []
}

actor MusicImporter {
    let writer: LibraryWriter
    init(writer: LibraryWriter) { self.writer = writer }
    static let extensions: Set<String> = ["flac","m4a","alac","wav","aif","aiff"]

    func run(_ roots: [URL], progress: @Sendable (ImportProgress) async -> Void) async -> ImportProgress {
        var state = ImportProgress()
        let fm = FileManager.default
        for root in roots {
            if Task.isCancelled { state.cancelled = true; break }
            let scoped = root.startAccessingSecurityScopedResource()
            defer { if scoped { root.stopAccessingSecurityScopedResource() } }
            do {
                let values = try root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                if values.isSymbolicLink == true { continue }
                if values.isDirectory == true {
                    // Enumeration stays on this worker actor; files are processed incrementally.
                    var enumerationFailed = false
                    guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey,.isSymbolicLinkKey], options:[.skipsHiddenFiles,.skipsPackageDescendants], errorHandler: { _, _ in enumerationFailed = true; return true }) else { throw CocoaError(.fileReadNoPermission) }
                    while let file = enumerator.nextObject() as? URL {
                        try Task.checkCancellation()
                        let v = try file.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey])
                        guard v.isRegularFile == true, v.isSymbolicLink != true,
                              Self.extensions.contains(file.pathExtension.lowercased()) else { continue }
                        state.discovered += 1
                        await progress(state)
                        await importOne(file, folder: root.lastPathComponent, state: &state)
                        await progress(state)
                    }
                    if enumerationFailed { state.failures += 1 }
                } else if Self.extensions.contains(root.pathExtension.lowercased()) {
                    state.discovered += 1
                    await importOne(root, folder: "Selected files", state: &state)
                } else { state.failures += 1 }
            } catch is CancellationError { state.cancelled = true; break }
            catch { state.failures += 1; if state.issues.count < 20 { state.issues.append(root.lastPathComponent + ": " + error.localizedDescription) } }
            await progress(state)
        }
        state.scanning = false
        state.cancelled = state.cancelled || Task.isCancelled
        await progress(state)
        return state
    }

    private func importOne(_ source: URL, folder: String, state: inout ImportProgress) async {
        defer { state.processed += 1 }
        do {
            try Task.checkCancellation()
            let staging = try LibraryPaths.directory("Staging").appendingPathComponent(UUID().uuidString).appendingPathExtension(source.pathExtension.lowercased())
            defer { try? FileManager.default.removeItem(at: staging) }
            let (hash,size) = try Self.coordinatedCopy(source, to: staging)
            let existing = try await writer.existingFilename(hash)
            if let existing,
               FileManager.default.fileExists(atPath:try LibraryPaths.directory("Music").appendingPathComponent(existing).path) {
                state.duplicates += 1; return
            }
            let metadata = try await MetadataReader.read(staging)
            try Task.checkCancellation()
            let filename = hash + "." + source.pathExtension.lowercased()
            let destination = try LibraryPaths.directory("Music").appendingPathComponent(filename)
            let created = !FileManager.default.fileExists(atPath: destination.path)
            if created { try FileManager.default.moveItem(at: staging, to: destination) }
            var artwork: String?
            if let data = metadata.artwork {
                let key = hash + ".jpg"
                let url = try LibraryPaths.directory("Artwork").appendingPathComponent(key)
                if (try? MetadataReader.saveArtwork(data, to: url)) != nil { artwork = key }
            }
            do {
                let inserted = try await writer.insert(ImportedSong(hash:hash,filename:filename,metadata:metadata,size:size,artwork:artwork,folder:folder))
                if inserted { state.imported += 1 } else { state.restored += 1 }
            } catch {
                if created { try? FileManager.default.removeItem(at: destination) }
                throw error
            }
        } catch is CancellationError { state.cancelled = true }
        catch { state.failures += 1; if state.issues.count < 20 { state.issues.append(source.lastPathComponent + ": " + error.localizedDescription) } }
    }

    static func coordinatedCopy(_ source: URL, to destination: URL) throws -> (String,Int64) {
        var coordinatorError: NSError?
        var result: Result<(String,Int64),Error> = .failure(CocoaError(.fileReadUnknown))
        NSFileCoordinator().coordinate(readingItemAt: source, options: [], error: &coordinatorError) { safeURL in
            result = Result {
                let input = try FileHandle(forReadingFrom: safeURL); defer { try? input.close() }
                guard FileManager.default.createFile(atPath: destination.path, contents:nil, attributes:[.protectionKey:FileProtectionType.completeUntilFirstUserAuthentication]) else { throw CocoaError(.fileWriteUnknown) }
                let output = try FileHandle(forWritingTo: destination); defer { try? output.close() }
                var hash = SHA256(); var size:Int64 = 0
                while true {
                    try Task.checkCancellation()
                    let chunk = try input.read(upToCount: 1024*1024) ?? Data()
                    if chunk.isEmpty { break }
                    hash.update(data:chunk); size += Int64(chunk.count)
                    try output.write(contentsOf:chunk)
                }
                try output.synchronize()
                return (hash.finalize().map { String(format:"%02x",$0) }.joined(),size)
            }
        }
        if let coordinatorError { throw coordinatorError }
        return try result.get()
    }
}

@MainActor @Observable
final class ImportController {
    var state = ImportProgress(scanning:false)
    var running = false
    var report: String?
    private var task: Task<Void,Never>?
    func start(_ urls: [URL], container: ModelContainer) {
        guard !running else { return }
        running = true; state = ImportProgress(); report = nil
        task = Task {
            let importer = await Task.detached { MusicImporter(writer:LibraryWriter(modelContainer:container)) }.value
            let final = await importer.run(urls) { [weak self] value in await self?.update(value) }
            report = "\(final.imported) imported · \(final.duplicates) duplicates · \(final.restored) restored · \(final.failures) errors" + (final.cancelled ? " · Cancelled" : "")
            running = false
        }
    }
    private func update(_ value: ImportProgress) { state = value }
    func cancel() { task?.cancel() }
}
