import Foundation

actor LyricsStore {
    static let shared = LyricsStore()
    private let directory:URL?
    init(directory:URL? = nil) { self.directory = directory }
    private func url(_ key:String)throws->URL {
        try PrivateMusicFile.url(key+".lyrics",in:directory ?? LibraryPaths.directory("Lyrics"))
    }
    func read(_ key:String)throws->LyricsDocument? {
        let path = try url(key)
        guard FileManager.default.fileExists(atPath:path.path) else { return nil }
        let file = try FileHandle(forReadingFrom:path); defer { try? file.close() }
        let data = try file.read(upToCount:1_048_581) ?? Data()
        guard data.count <= 1_048_580,data.count >= 4 else { throw LyricsError.tooLarge }
        let header = String(data:data.prefix(4),encoding:.utf8)
        guard header == "LRC\n" || header == "TXT\n",let text = String(data:data.dropFirst(4),encoding:.utf8) else { throw LyricsError.invalidEncoding }
        return try LyricsDocument.parse(text,synchronized:header == "LRC\n")
    }
    func write(_ key:String,data:Data,synchronized:Bool)throws->LyricsDocument {
        guard data.count <= 1_048_576 else { throw LyricsError.tooLarge }
        guard let text = String(data:data,encoding:.utf8) else { throw LyricsError.invalidEncoding }
        let lyrics = try LyricsDocument.parse(text,synchronized:synchronized)
        try persist(data, to: key, synchronized: synchronized)
        return lyrics
    }
    private func persist(_ data: Data, to key: String, synchronized: Bool) throws {
        var bytes = Data((synchronized ? "LRC\n" : "TXT\n").utf8)
        bytes.append(data)
        try bytes.write(to: url(key), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    func importSidecar(_ key: String, from source: URL) throws -> Bool {
        guard !FileManager.default.fileExists(atPath: try url(key).path) else { return false }
        let data = try Self.readSource(source)
        guard data.count <= 1_048_576 else { throw LyricsError.tooLarge }
        guard let text = String(data: data, encoding: .utf8) else { throw LyricsError.invalidEncoding }
        let parsed = try LyricsDocument.parse(text, synchronized: true)
        guard !parsed.cues.isEmpty || !parsed.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try persist(data, to: key, synchronized: true)
        return true
    }

    nonisolated static func readSource(_ source: URL) throws -> Data {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        var coordinationError: NSError?
        var result: Result<Data, Error> = .failure(CocoaError(.fileReadUnknown))
        NSFileCoordinator().coordinate(readingItemAt: source, options: [], error: &coordinationError) { local in
            result = Result {
                let values = try local.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true else {
                    throw CocoaError(.fileReadNoPermission)
                }
                let file = try FileHandle(forReadingFrom: local)
                defer { try? file.close() }
                return try file.read(upToCount: 1_048_577) ?? Data()
            }
        }
        if let coordinationError { throw coordinationError }
        return try result.get()
    }

    func remove(_ key:String)throws {
        let path = try url(key)
        if FileManager.default.fileExists(atPath:path.path) { try FileManager.default.removeItem(at:path) }
    }
}
