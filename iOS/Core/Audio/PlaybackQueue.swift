import Foundation

enum RepeatMode: String, Codable, CaseIterable, Sendable { case off, one, all }

struct PlaybackQueue: Codable, Equatable, Sendable {
    private(set) var tracks: [PlaybackTrack] = []
    private(set) var index = 0
    var repeatMode: RepeatMode = .off
    var shuffle = false
    var current: PlaybackTrack? { tracks.indices.contains(index) ? tracks[index] : nil }
    mutating func replace(_ items:[PlaybackTrack],starting id:UUID) {
        tracks = items; index = items.firstIndex { $0.id == id } ?? 0
    }
    mutating func select(_ id:UUID) { if let i = tracks.firstIndex(where:{$0.id == id}) { index = i } }
    mutating func advance(automatic:Bool) -> Bool {
        guard !tracks.isEmpty else { return false }
        if automatic, repeatMode == .one { return true }
        if shuffle, tracks.count > 1 {
            let choices = tracks.indices.filter { $0 != index }
            if let next = choices.randomElement() { index = next }; return true
        }
        if index+1 < tracks.count { index += 1; return true }
        if repeatMode == .all { index = 0; return true }
        return false
    }
    mutating func previous() { if index > 0 { index -= 1 } else if repeatMode == .all { index = max(0,tracks.count-1) } }
}
