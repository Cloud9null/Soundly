import SwiftUI
import SwiftData

enum SmartRule:String,CaseIterable,Identifiable {
    case favorites = "Favorites", neverPlayed = "Never played", mostPlayed = "Most played", recent = "Added this month", hiRes = "Hi-Res sources", flac = "FLAC sources"
    var id:String { rawValue }
    func matches(_ song:Song,now:Date = Date())->Bool {
        switch self {
        case .favorites: song.favorite
        case .neverPlayed: song.playCount == 0
        case .mostPlayed: song.playCount > 0
        case .recent: song.dateAdded >= now.addingTimeInterval(-30*86400)
        case .hiRes: (song.bitDepth ?? 0) > 16 || song.sampleRate > 48000
        case .flac: song.codec.uppercased() == "FLAC"
        }
    }
    func ordered(_ songs:[Song])->[Song] {
        songs.filter { matches($0) }.sorted {
            if self == .mostPlayed,$0.playCount != $1.playCount { return $0.playCount > $1.playCount }
            if self == .recent,$0.dateAdded != $1.dateAdded { return $0.dateAdded > $1.dateAdded }
            if $0.title != $1.title { return $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}
struct SmartPlaylistsView:View {
    @Query private var songs:[Song]
    var body:some View {
        List {
            ForEach(SmartRule.allCases) { rule in
                NavigationLink { SmartPlaylistDetail(rule:rule) } label: {
                    HStack { Label(rule.rawValue,systemImage:"line.3.horizontal.decrease");Spacer();Text("\(songs.filter { rule.matches($0) }.count)").foregroundStyle(.secondary) }
                }.accessibilityIdentifier("smartRule-"+rule.rawValue)
            }
            Text("Local dynamic rules. Hi-Res describes source metadata, not output. Play counts record successful playback starts. Recent means the last 30 days.").font(.footnote).foregroundStyle(.secondary)
        }.navigationTitle("Smart Playlists").soundlySurface()
    }
}
struct SmartPlaylistDetail:View {
    let rule:SmartRule
    @Query private var songs:[Song]
    @Environment(PlaybackController.self) private var playback
    var body:some View {
        let tracks = rule.ordered(songs)
        List {
            if tracks.isEmpty { ContentUnavailableView("No matching tracks",systemImage:"music.note.list") }
            ForEach(tracks) { song in
                Button { playback.play(song,within:tracks) } label: {
                    HStack(spacing:12) {
                        CoverView(artwork:song.artwork,size:48)
                        VStack(alignment:.leading) { Text(song.title).foregroundStyle(.primary);Text(song.artist).font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        if !song.available { Image(systemName:"exclamationmark.triangle") }
                    }
                }.buttonStyle(.plain).disabled(!song.available)
            }
        }.navigationTitle(rule.rawValue).soundlySurface()
    }
}
