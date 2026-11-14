import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LyricsView:View {
    @Environment(PlaybackController.self) private var playback
    @Environment(\.modelContext) private var context
    @State private var lyrics:LyricsDocument?
    @State private var key:String?
    @State private var importing = false
    @State private var importKey:String?
    @State private var confirming = false
    @State private var removalKey:String?
    @State private var busy = false
    @State private var error:String?
    var body:some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment:.leading,spacing:20) {
                    if let lyrics {
                        if lyrics.cues.isEmpty { Text(lyrics.text).font(.title3).textSelection(.enabled) }
                        else {
                            ForEach(lyrics.cues) { cue in
                                Button { playback.seek(cue.time) } label: {
                                    Text(cue.text.isEmpty ? "♪" : cue.text).font(.title2.weight(.semibold))
                                        .foregroundStyle(lyrics.cue(at:playback.audio.elapsed)?.time == cue.time ? Color.primary : Color.secondary)
                                        .frame(maxWidth:.infinity,minHeight:44,alignment:.leading).contentShape(Rectangle())
                                }.buttonStyle(.plain).disabled(playback.busy).id(cue.time)
                                    .accessibilityValue(lyrics.cue(at:playback.audio.elapsed)?.time == cue.time ? "Current line" : "")
                            }
                        }
                    } else { ContentUnavailableView("Your words, offline",systemImage:"text.quote",description:Text("Import UTF-8 LRC or TXT lyrics for this track. No online lyrics service is contacted.")) }
                    if let error { Text(error).font(.footnote).foregroundStyle(.secondary) }
                }.padding()
            }.onChange(of:lyrics?.cue(at:playback.audio.elapsed)?.time) { _, time in if let time { proxy.scrollTo(time,anchor:.center) } }
        }.navigationTitle("Lyrics").soundlySurface()
            .toolbar {
                ToolbarItem(placement:.topBarTrailing) {
                    Menu("Lyrics options",systemImage:"ellipsis") {
                        Button("Import LRC / TXT",systemImage:"square.and.arrow.down") { importKey = key; importing = true }.disabled(key == nil || busy)
                        Button("Remove local lyrics",role:.destructive) { removalKey = key; confirming = true }.disabled(lyrics == nil || busy)
                    }
                }
            }
            .confirmationDialog("Remove lyrics for this track?",isPresented:$confirming,titleVisibility:.visible) {
                Button("Remove lyrics",role:.destructive) {
                    guard let key = removalKey else { return };busy = true
                    Task {
                        defer { busy = false }
                        do { try await LyricsStore.shared.remove(key); if self.key == key { lyrics = nil;error = nil } }
                        catch { if self.key == key { self.error = "Could not remove local lyrics." } }
                    }
                }
            }
            .task(id:playback.current?.id) {
                lyrics = nil;key = nil;error = nil
                guard let id = playback.current?.id else { return }
                do {
                    var query = FetchDescriptor<Song>(predicate:#Predicate { $0.id == id });query.fetchLimit = 1
                    guard let song = try context.fetch(query).first else { return }
                    let hash = song.fileHash;key = hash
                    let result = try await LyricsStore.shared.read(hash)
                    guard !Task.isCancelled else { return };lyrics = result
                } catch { if !Task.isCancelled { self.error = "Could not read local lyrics. Files were preserved." } }
            }
            .fileImporter(isPresented:$importing,allowedContentTypes:[.data]) { result in
                if case .failure(let failure) = result {
                    let failure = failure as NSError
                    if failure.domain == NSCocoaErrorDomain && failure.code == NSUserCancelledError { return }
                }
                guard let key = importKey else { return };busy = true
                Task {
                    defer { busy = false }
                    do {
                        let url = try result.get();let ext = url.pathExtension.lowercased()
                        guard ["lrc","txt"].contains(ext) else { throw CocoaError(.fileReadUnknown) }
                        let bytes = try await Task.detached {
                            let scoped = url.startAccessingSecurityScopedResource();defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                            let file = try FileHandle(forReadingFrom:url);defer { try? file.close() }
                            return try file.read(upToCount:1_048_577) ?? Data()
                        }.value
                        let result = try await LyricsStore.shared.write(key,data:bytes,synchronized:ext == "lrc")
                        if self.key == key { lyrics = result;error = nil }
                    } catch { if self.key == key { self.error = "Import failed. Existing lyrics were preserved. Use UTF-8 LRC/TXT up to 1 MiB." } }
                }
            }
    }
}
