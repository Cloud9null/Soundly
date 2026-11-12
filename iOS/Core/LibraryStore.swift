import Foundation
import SwiftData

@Model
final class Song {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var hash: String
    var filename: String
    var title: String
    var artist: String
    var album: String
    var albumArtist: String
    var genre: String
    var composer: String
    var trackNumber: Int
    var discNumber: Int
    var duration: Double
    var sampleRate: Double
    var bitDepth: Int?
    var channels: Int
    var codec: String
    var fileSize: Int64
    var artwork: String?
    var dateAdded: Date
    var lastPlayed: Date?
    var playCount: Int
    var favorite: Bool
    var available: Bool
    var originalFolder: String
    init(_ item: ImportedSong) {
        id = UUID(); hash = item.hash; filename = item.filename
        title = item.metadata.title; artist = item.metadata.artist; album = item.metadata.album
        albumArtist = item.metadata.albumArtist; genre = item.metadata.genre; composer = item.metadata.composer
        trackNumber = item.metadata.track; discNumber = item.metadata.disc
        duration = item.metadata.duration; sampleRate = item.metadata.rate
        bitDepth = item.metadata.bits; channels = item.metadata.channels; codec = item.metadata.codec
        fileSize = item.size; artwork = item.artwork; dateAdded = Date()
        playCount = 0; favorite = false; available = true; originalFolder = item.folder
    }
    var quality: String {
        "\(codec) · \(bitDepth.map { "\($0)-bit" } ?? "Depth unknown") · \(String(format: "%.1f", sampleRate / 1000)) kHz"
    }
}

struct ImportedSong: Sendable {
    let hash: String
    let filename: String
    let metadata: MusicMetadata
    let size: Int64
    let artwork: String?
    let folder: String
}

enum LibraryPaths {
    static func base() throws -> URL {
        let url = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Soundly", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        var protected = url
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try protected.setResourceValues(values)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
        return url
    }
    static func directory(_ name: String) throws -> URL {
        let url = try base().appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

@ModelActor
actor LibraryWriter {
    func contains(_ hash: String) throws -> Bool {
        var q = FetchDescriptor<Song>(predicate: #Predicate { $0.hash == hash }); q.fetchLimit = 1
        return try modelContext.fetchCount(q) > 0
    }
    func insert(_ item: ImportedSong) throws -> Bool {
        if try contains(item.hash) { return false }
        modelContext.insert(Song(item))
        do { try modelContext.save(); return true }
        catch { modelContext.rollback(); throw error }
    }
    func clearArtwork() throws {
        let directory = try LibraryPaths.directory("Artwork")
        for file in try FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil) {
            try FileManager.default.removeItem(at:file)
        }
        for song in try modelContext.fetch(FetchDescriptor<Song>()) { song.artwork = nil }
        try modelContext.save()
    }
    func rescan() async throws -> Int {
        let music = try LibraryPaths.directory("Music")
        let songs = try modelContext.fetch(FetchDescriptor<Song>())
        for song in songs {
            try Task.checkCancellation()
            let url = music.appendingPathComponent(song.filename)
            song.available = FileManager.default.fileExists(atPath:url.path)
            if song.available, let m = try? await MetadataReader.read(url) {
                song.title = m.title; song.artist = m.artist; song.album = m.album
                song.albumArtist = m.albumArtist; song.genre = m.genre; song.composer = m.composer
                song.trackNumber = m.track; song.discNumber = m.disc
                song.duration = m.duration; song.sampleRate = m.rate
                song.bitDepth = m.bits; song.channels = m.channels; song.codec = m.codec
                if let data = m.artwork {
                    let key = song.hash + ".jpg"
                    if let target = try? LibraryPaths.directory("Artwork").appendingPathComponent(key),
                       (try? MetadataReader.saveArtwork(data,to:target)) != nil { song.artwork = key }
                }
            }
        }
        try modelContext.save()
        return songs.filter { !$0.available }.count
    }
}
