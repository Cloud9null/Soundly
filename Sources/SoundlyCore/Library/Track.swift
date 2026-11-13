import Foundation

/// Persistence-independent value type. The database adapter owns migrations and indexing.
public struct Track: Identifiable, Equatable, Sendable {
    public let id: UUID
    /// Content hash of the imported bytes for deduplication, NOT output audio verification.
    public let fileSHA256: String
    /// Relative to Application Support/Music; never persist a sandbox absolute URL.
    public let internalFilename: String
    public var title: String
    public var artist: String?
    public var album: String?
    public var albumArtist: String?
    public var genres: [String]
    public var composer: String?
    public var trackNumber: Int?
    public var discNumber: Int?
    public var duration: TimeInterval?
    public var sourcePCM: PCMFormat?
    /// Read from content/stream metadata, not inferred from an extension such as m4a.
    public var codec: String?
    public var isLossless: Bool?
    public let fileSize: Int64
    public var artworkKey: String?
    public let dateAdded: Date
    public var lastPlayed: Date?
    public var playCount: Int
    public var isFavorite: Bool

    public enum ValidationError: Error {
        case invalidHash, unsafeFilename, invalidFileSize
    }

    public init(id: UUID = UUID(), fileSHA256: String, internalFilename: String,
                title: String, fileSize: Int64, dateAdded: Date = Date()) throws {
        let hex = Set("0123456789abcdef")
        guard fileSHA256.count == 64, fileSHA256.allSatisfy({ hex.contains($0) }) else {
            throw ValidationError.invalidHash
        }
        guard !internalFilename.isEmpty,
              internalFilename != ".", internalFilename != "..",
              !internalFilename.contains("/"), !internalFilename.contains("\\"),
              !internalFilename.contains("\0") else {
            throw ValidationError.unsafeFilename
        }
        guard fileSize >= 0 else { throw ValidationError.invalidFileSize }
        self.id = id
        self.fileSHA256 = fileSHA256
        self.internalFilename = internalFilename
        self.title = title
        self.fileSize = fileSize
        self.dateAdded = dateAdded
        genres = []
        playCount = 0
        isFavorite = false
    }
}
