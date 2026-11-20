import Foundation

public struct M3UEntry:Codable,Equatable,Sendable {
    public var reference:String
    public var title:String?
    public var duration:Double?
    public var sha256:String?
    public init(reference:String,title:String? = nil,duration:Double? = nil,sha256:String? = nil) {
        self.reference = reference;self.title = title;self.duration = duration;self.sha256 = sha256
    }
}
public struct M3UCatalogItem:Sendable {
    public var hash:String
    public var filename:String
    public var title:String
    public var artist:String
    public init(hash:String,filename:String,title:String,artist:String) {
        self.hash = hash;self.filename = filename;self.title = title;self.artist = artist
    }
}
public struct M3UImport:Sendable {
    public var entries:[M3UEntry]
    public var remoteCount:Int
    public var invalidCount:Int
}
public struct M3UResolution:Sendable {
    public var hashes:[String]
    public var unresolved:[M3UEntry]
    public var duplicateCount:Int
    public var ambiguousCount:Int
}
public enum M3UError:Error { case tooLarge, invalidEncoding, invalidEntry, streamingPlaylist }

/// Original local-only M3U implementation. References are identifiers for matching, never file-access grants.
public enum M3U {
    public static let byteLimit = 2*1024*1024
    public static let entryLimit = 20000
    public static func validHash(_ value:String)->Bool {
        value.count == 64 && value.allSatisfy { "0123456789abcdef".contains($0) }
    }
    public static func valid(_ entry:M3UEntry)->Bool {
        guard !entry.reference.isEmpty,entry.reference.count <= 1024,
              entry.reference != ".",entry.reference != "..",!entry.reference.hasPrefix("#"),
              !entry.reference.contains("/"),!entry.reference.contains("\\"),
              !entry.reference.unicodeScalars.contains(where:CharacterSet.controlCharacters.contains),
              (entry.title?.count ?? 0) <= 1000,
              !(entry.title ?? "").unicodeScalars.contains(where:{ CharacterSet.controlCharacters.contains($0) && !CharacterSet.newlines.contains($0) && $0.value != 9 }) else { return false }
        if let hash = entry.sha256,!validHash(hash) { return false }
        if let duration = entry.duration,(!duration.isFinite || duration < 0 || duration > 315_360_000) { return false }
        return true
    }
    public static func parse(_ bytes:Data,strictUTF8:Bool = true)throws->M3UImport {
        guard bytes.count <= byteLimit else { throw M3UError.tooLarge }
        let decoded = String(data:bytes,encoding:.utf8) ?? (strictUTF8 ? nil : String(data:bytes,encoding:.windowsCP1252))
        guard let decoded,!decoded.contains("\0") else { throw M3UError.invalidEncoding }
        let text = decoded.trimmingCharacters(in:CharacterSet(charactersIn:"\u{feff}")).replacingOccurrences(of:"\r",with:"\n")
        var entries:[M3UEntry] = [];var title:String?;var duration:Double?;var hash:String?
        var remote = 0;var invalid = 0;var references = 0
        for raw in text.components(separatedBy:"\n") {
            let line = raw.trimmingCharacters(in:.whitespaces)
            if line.isEmpty { continue }
            if line.uppercased().hasPrefix("#EXT-X-") { throw M3UError.streamingPlaylist }
            if line.uppercased().hasPrefix("#EXTINF:") {
                if let comma = line.firstIndex(of:",") {
                    let value = String(line[line.index(after:comma)...]).trimmingCharacters(in:.whitespaces)
                    title = value.isEmpty ? nil : String(value.prefix(1000))
                    let number = Double(line.dropFirst(8).prefix { $0 != "," && $0 != " " })
                    duration = number.flatMap { $0.isFinite && $0 >= 0 && $0 <= 315_360_000 ? $0 : nil }
                }
                continue
            }
            if line.hasPrefix("#SOUNDLY-SHA256:") {
                let value = String(line.dropFirst(16)).trimmingCharacters(in:.whitespaces).lowercased()
                guard validHash(value) else { throw M3UError.invalidEntry };hash = value;continue
            }
            if line.hasPrefix("#") { continue }
            references += 1;guard references <= entryLimit else { throw M3UError.tooLarge }
            defer { title = nil;duration = nil;hash = nil }
            var path = line
            let windowsDrive = path.count > 2 && path[path.index(after:path.startIndex)] == ":" && (path.dropFirst(2).hasPrefix("\\") || path.dropFirst(2).hasPrefix("/"))
            if !windowsDrive,let scheme = URL(string:path)?.scheme {
                guard scheme.lowercased() == "file",let url = URL(string:path),url.host == nil || url.host == "" || url.host == "localhost" else { remote += 1;continue }
                path = url.path
            } else if path.hasPrefix("//") || path.hasPrefix("\\\\") { remote += 1;continue }
            path = path.replacingOccurrences(of:"\\",with:"/")
            let last = String(path.split(separator:"/",omittingEmptySubsequences:false).last ?? "")
            let reference = last.removingPercentEncoding ?? last
            let entry = M3UEntry(reference:reference,title:title,duration:duration,sha256:hash)
            guard valid(entry) else { invalid += 1;continue }
            entries.append(entry)
        }
        return M3UImport(entries:entries,remoteCount:remote,invalidCount:invalid)
    }
    public static func encode(_ entries:[M3UEntry])throws->Data {
        guard entries.count <= entryLimit else { throw M3UError.tooLarge }
        var lines = ["#EXTM3U"]
        for entry in entries {
            guard valid(entry) else { throw M3UError.invalidEntry }
            let label = (entry.title ?? entry.reference).components(separatedBy:.newlines).joined(separator:" ").replacingOccurrences(of:"\t",with:" ")
            lines.append("#EXTINF:\(entry.duration.map { Int($0) } ?? -1),\(label)")
            if let hash = entry.sha256 { lines.append("#SOUNDLY-SHA256:"+hash) }
            lines.append(entry.reference)
        }
        let data = Data((lines.joined(separator:"\n")+"\n").utf8)
        guard data.count <= byteLimit else { throw M3UError.tooLarge };return data
    }
    public static func resolve(_ entries:[M3UEntry],catalog:[M3UCatalogItem])->M3UResolution {
        func normalized(_ value:String)->String { value.trimmingCharacters(in:.whitespacesAndNewlines).folding(options:[.caseInsensitive],locale:Locale(identifier:"en_US_POSIX")) }
        var files:[String:Set<String>] = [:];var labels:[String:Set<String>] = [:];var hashes = Set<String>()
        for track in catalog {
            hashes.insert(track.hash);files[normalized(track.filename),default:[]].insert(track.hash)
            labels[normalized(track.title),default:[]].insert(track.hash)
            labels[normalized(track.artist+" - "+track.title),default:[]].insert(track.hash)
        }
        var result = M3UResolution(hashes:[],unresolved:[],duplicateCount:0,ambiguousCount:0);var seen = Set<String>()
        for entry in entries {
            var candidates = Set<String>()
            if let hash = entry.sha256 { if hashes.contains(hash) { candidates.insert(hash) } }
            else {
                candidates = files[normalized(entry.reference)] ?? []
                if candidates.isEmpty,let title = entry.title { candidates = labels[normalized(title)] ?? [] }
                if candidates.isEmpty { candidates = labels[normalized((entry.reference as NSString).deletingPathExtension)] ?? [] }
            }
            if candidates.count == 1,let value = candidates.first {
                if seen.insert(value).inserted { result.hashes.append(value) } else { result.duplicateCount += 1 }
            } else {
                result.unresolved.append(entry);if candidates.count > 1 { result.ambiguousCount += 1 }
            }
        }
        return result
    }
}
