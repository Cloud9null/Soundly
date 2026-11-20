import SwiftUI
import SwiftData

struct LyricsView:View {
    let showArtwork: () -> Void
    @Environment(\.soundlySurface) private var surface
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var currentLine: Double? { lyrics?.cue(at: playback.audio.elapsed)?.time }
    var body:some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Button("Show artwork", systemImage: "photo", action: showArtwork)
                    .labelStyle(.iconOnly).frame(width: 44, height: 44)
                Text(lyrics?.cues.isEmpty == false ? "Synced Lyrics" : "Lyrics")
                    .font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Menu("Lyrics options", systemImage: "ellipsis") {
                    Button("Import LRC / TXT", systemImage: "square.and.arrow.down", action: prepareImport)
                        .disabled(key == nil || busy)
                    Button("Remove local lyrics", role: .destructive) { removalKey = key; confirming = true }
                        .disabled(lyrics == nil || busy)
                }.labelStyle(.iconOnly).frame(width: 44, height: 44)
            }.padding(.horizontal, 4)
            Divider()
            lines
        }
        .background(surface)
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
                    let bytes = try await Task.detached { try LyricsStore.readSource(url) }.value
                    let result = try await LyricsStore.shared.write(key,data:bytes,synchronized:ext == "lrc")
                    if self.key == key { lyrics = result;error = nil }
                } catch { if self.key == key { self.error = "Import failed. Existing lyrics were preserved. Use UTF-8 LRC/TXT up to 1 MiB." } }
            }
        }
    }
    private var lines: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment:.leading,spacing:12) {
                    if let lyrics {
                        if lyrics.cues.isEmpty { Text(lyrics.text).font(.title3).textSelection(.enabled) }
                        else {
                            ForEach(lyrics.cues) { cue in
                                let isCurrent = currentLine == cue.time
                                Button { playback.seek(cue.time) } label: {
                                    Text(cue.text.isEmpty ? "♪" : cue.text)
                                        .font(.title3.weight(isCurrent ? .bold : .semibold))
                                        .foregroundStyle(isCurrent ? Color.primary : Color.secondary)
                                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .background(isCurrent ? Color.accentColor.opacity(0.13) : .clear,
                                                    in: RoundedRectangle(cornerRadius: 14))
                                        .contentShape(Rectangle())
                                }.buttonStyle(.plain).disabled(playback.busy).id(cue.time)
                                    .accessibilityValue(isCurrent ? "Current line" : "")
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No lyrics for this track").font(.headline)
                            Text("Import an LRC for synced lyrics or a TXT for plain lyrics.")
                                .font(.footnote).foregroundStyle(.secondary)
                            Button("Import lyrics", systemImage: "square.and.arrow.down", action: prepareImport)
                                .buttonStyle(.glass).disabled(key == nil || busy)
                        }.padding(.vertical, 6)
                    }
                    if let error { Text(error).font(.footnote).foregroundStyle(.secondary) }
                }.padding()
            }.onChange(of: currentLine, initial: true) { _, time in
                guard let time else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                    proxy.scrollTo(time, anchor: .center)
                }
            }
        }
    }

    private func prepareImport() {
        importKey = key
        importing = true
    }
}
