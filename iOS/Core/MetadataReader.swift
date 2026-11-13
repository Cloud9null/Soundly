import Foundation
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

struct MusicMetadata: Sendable {
    var title = ""
    var artist = "Unknown Artist"
    var album = "Unknown Album"
    var albumArtist = ""
    var genre = ""
    var composer = ""
    var track = 0
    var disc = 0
    var duration = 0.0
    var rate = 0.0
    var bits: Int?
    var channels = 0
    var codec = "Unknown"
    var artwork: Data?
}

enum MetadataReader {
    static func read(_ url: URL, fallbackTitle: String? = nil) async throws -> MusicMetadata {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1) else { throw CocoaError(.fileReadCorruptFile) }
        try file.read(into: buffer, frameCount: 1)
        guard buffer.frameLength > 0 else { throw CocoaError(.fileReadCorruptFile) }
        var m = MusicMetadata(); m.title = fallbackTitle ?? url.deletingPathExtension().lastPathComponent
        m.rate = format.sampleRate; m.channels = Int(format.channelCount)
        m.duration = Double(file.length) / format.sampleRate
        let asbd = file.fileFormat.streamDescription.pointee
        switch asbd.mFormatID {
        case kAudioFormatFLAC: m.codec = "FLAC"
        case kAudioFormatAppleLossless:
            m.codec = "ALAC"; m.bits = [1:16,2:20,3:24,4:32][Int(asbd.mFormatFlags)]
        case kAudioFormatLinearPCM:
            m.codec = "PCM"; m.bits = asbd.mBitsPerChannel > 0 ? Int(asbd.mBitsPerChannel) : nil
        default: throw CocoaError(.fileReadUnsupportedScheme)
        }
        let asset = AVURLAsset(url: url)
        let items = (try? await asset.load(.metadata)) ?? []
        for item in items {
            try Task.checkCancellation()
            let key = item.commonKey?.rawValue ?? ""
            let identifier = item.identifier?.rawValue ?? ""
            if identifier.contains("trkn") || identifier.contains("disk") {
                if let data = try? await item.load(.dataValue), data.count >= 4 {
                    let b = Array(data); let n = Int(b[2]) << 8 | Int(b[3])
                    if identifier.contains("trkn") { m.track = n } else { m.disc = n }
                }
            }
            if key == "artwork" {
                if let data = try? await item.load(.dataValue), data.count <= 8 * 1024 * 1024 { m.artwork = data }
                continue
            }
            guard let value = try? await item.load(.stringValue), !value.isEmpty else { continue }
            switch key {
            case "title": m.title = value
            case "artist": m.artist = value
            case "albumName": m.album = value
            case "type": m.genre = value
            case "creator": m.composer = value
            default:
                if identifier.contains("TPE2") || identifier.contains("albumArtist") || identifier.contains("aART") { m.albumArtist = value }
                if identifier.contains("TCOM") || identifier.contains("composer") || identifier.contains("©wrt") { m.composer = value }
                if identifier.contains("TCON") || identifier.contains("©gen") { m.genre = value }
                if identifier.contains("TRCK") { m.track = Int(value.split(separator: "/").first ?? "") ?? 0 }
                if identifier.contains("TPOS") { m.disc = Int(value.split(separator: "/").first ?? "") ?? 0 }
            }
        }
        if m.codec == "FLAC" { try FLACMetadata.read(url, into: &m) }
        if m.albumArtist.isEmpty { m.albumArtist = m.artist }
        return m
    }
    static func saveArtwork(_ data: Data, to url: URL) throws {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways:true, kCGImageSourceThumbnailMaxPixelSize:800, kCGImageSourceCreateThumbnailWithTransform:true] as CFDictionary),
              let target = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { throw CocoaError(.fileReadCorruptFile) }
        CGImageDestinationAddImage(target, image, [kCGImageDestinationLossyCompressionQuality:0.85] as CFDictionary)
        guard CGImageDestinationFinalize(target) else { throw CocoaError(.fileWriteUnknown) }
    }
}

/// Bounded FLAC STREAMINFO/Vorbis parser supplements Apple's common metadata.
/// Unknown fields are kept unknown; malformed lengths throw rather than indexing beyond buffers.
enum FLACMetadata {
    static func read(_ url: URL, into m: inout MusicMetadata) throws {
        let f = try FileHandle(forReadingFrom: url); defer { try? f.close() }
        func bytes(_ n: Int) throws -> [UInt8] {
            let b = Array(try f.read(upToCount: n) ?? Data())
            guard b.count == n else { throw CocoaError(.fileReadCorruptFile) }; return b
        }
        guard try bytes(4) == Array("fLaC".utf8) else { throw CocoaError(.fileReadCorruptFile) }
        var total = 0
        while true {
            try Task.checkCancellation()
            let header = try bytes(4)
            let length = Int(header[1]) << 16 | Int(header[2]) << 8 | Int(header[3])
            total += length
            guard total <= 32 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
            let b = try bytes(length)
            if header[0] & 0x7f == 0 {
                guard b.count == 34 else { throw CocoaError(.fileReadCorruptFile) }
                m.rate = Double(Int(b[10]) << 12 | Int(b[11]) << 4 | Int(b[12]) >> 4)
                m.channels = Int((b[12] >> 1) & 7) + 1
                m.bits = Int((b[12] & 1) << 4 | b[13] >> 4) + 1
            }
            if header[0] & 0x7f == 4 {
                var i = 0
                func uint32() throws -> Int {
                    guard i + 4 <= b.count else { throw CocoaError(.fileReadCorruptFile) }
                    defer { i += 4 }
                    return (0..<4).reduce(0) { $0 | Int(b[i+$1]) << ($1*8) }
                }
                func string() throws -> String {
                    let n = try uint32(); guard n <= b.count-i else { throw CocoaError(.fileReadCorruptFile) }
                    defer { i += n }; return String(decoding:b[i..<i+n],as:UTF8.self)
                }
                _ = try string(); let count = try uint32()
                guard count <= 100_000 else { throw CocoaError(.fileReadCorruptFile) }
                for _ in 0..<count {
                    let s = try string().split(separator:"=",maxSplits:1,omittingEmptySubsequences:false)
                    guard s.count == 2 else { continue }; let value = String(s[1])
                    switch s[0].uppercased() {
                    case "TITLE": m.title = value
                    case "ARTIST": m.artist = value
                    case "ALBUM": m.album = value
                    case "ALBUMARTIST", "ALBUM ARTIST": m.albumArtist = value
                    case "GENRE": m.genre = m.genre.isEmpty ? value : m.genre + "; " + value
                    case "COMPOSER": m.composer = value
                    case "TRACKNUMBER": m.track = Int(value) ?? 0
                    case "DISCNUMBER": m.disc = Int(value) ?? 0
                    default: break
                    }
                }
            }
            // PICTURE: type, MIME length/data, description length/data, four dimensions, image length/data.
            if header[0] & 0x7f == 6, m.artwork == nil {
                var i = 4
                func big() throws -> Int {
                    guard i+4 <= b.count else { throw CocoaError(.fileReadCorruptFile) }
                    defer { i += 4 }; return (0..<4).reduce(0) { $0 << 8 | Int(b[i+$1]) }
                }
                let mime = try big(); guard mime <= b.count-i else { throw CocoaError(.fileReadCorruptFile) }; i += mime
                let description = try big(); guard description <= b.count-i else { throw CocoaError(.fileReadCorruptFile) }; i += description
                guard i+16 <= b.count else { throw CocoaError(.fileReadCorruptFile) }; i += 16
                let n = try big(); guard n <= b.count-i else { throw CocoaError(.fileReadCorruptFile) }
                if n <= 8*1024*1024 { m.artwork = Data(b[i..<i+n]) }
            }
            if header[0] & 0x80 != 0 { break }
        }
    }
}
