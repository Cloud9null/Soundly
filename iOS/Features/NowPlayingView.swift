import SwiftUI
import SwiftData
import AVFoundation
import AVKit

struct NowPlayingView: View {
    @Environment(PlaybackController.self) private var playback
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.soundlySurface) private var surface
    @State private var position = 0.0
    @State private var dragging = false
    @State private var favorite = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing:24) {
                    CoverView(artwork:playback.current?.artwork,size:260)
                    Text(playback.current?.title ?? "Nothing playing").font(.title2.bold()).multilineTextAlignment(.center)
                    if let error = playback.error { Text(error).font(.footnote).foregroundStyle(.red) }
                    if let song = playback.current {
                        Text(song.artist).font(.title3).foregroundStyle(.secondary)
                        Text(song.album).foregroundStyle(.secondary)
                        Text(song.sourceQuality).font(.caption.monospaced()).padding().glassEffect()
                        Text("Source file properties only").font(.caption).foregroundStyle(.secondary)
                        Slider(value:$position,in:0...max(1,playback.audio.duration)) { editing in
                            dragging = editing
                            if !editing { playback.seek(position) }
                        }.accessibilityLabel("Playback position").disabled(playback.busy)
                        HStack {
                            Text(Self.time(position)); Spacer()
                            Text("−"+Self.time(max(0,playback.audio.duration-position)))
                        }.font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        HStack(spacing:32) {
                            Button("Previous",systemImage:"backward.end.fill") { playback.previous() }
                            Button(playback.audio.playing ? "Pause" : "Play",systemImage:playback.audio.playing ? "pause.circle.fill" : "play.circle.fill") { playback.toggle() }.font(.system(size:62))
                            Button("Next",systemImage:"forward.end.fill") { playback.next() }
                        }.labelStyle(.iconOnly).font(.title).disabled(playback.busy)
                        HStack(spacing:24) {
                            Button("Shuffle",systemImage:"shuffle") { playback.toggleShuffle() }.tint(playback.queue.shuffle ? .accentColor : .secondary).accessibilityValue(playback.queue.shuffle ? "On" : "Off")
                            Button("Repeat",systemImage:playback.queue.repeatMode == .one ? "repeat.1" : "repeat") { playback.cycleRepeat() }.tint(playback.queue.repeatMode == .off ? .secondary : .accentColor).accessibilityValue(playback.queue.repeatMode.rawValue)
                            Button(favorite ? "Unfavorite" : "Favorite",systemImage:favorite ? "heart.fill" : "heart") { changeFavorite() }
                            NavigationLink("Queue",destination:QueueView()).labelStyle(.titleOnly)
                        }.font(.title3)
                        HStack {
                            Button("Stop",systemImage:"stop.fill") { playback.stop() }
                            Spacer()
                            SystemRoutePicker().frame(width:44,height:44).accessibilityLabel("Choose audio output")
                        }
                        NavigationLink("Signal Path",destination:SignalPathView()).accessibilityIdentifier("openSignalPath")
                    } else {
                        Text("Choose a song from your library to begin.").foregroundStyle(.secondary)
                    }
                    Label(playback.audio.signalPath.assessment.status.rawValue,systemImage:"info.circle").font(.footnote).padding().glassEffect()
                }.padding(24)
            }
            .background {
                ZStack {
                surface
                if let artwork = playback.current?.artwork, !reduceTransparency {
                    CoverView(artwork:artwork,size:500).blur(radius:80).opacity(0.25).allowsHitTesting(false)
                }
                }
            }
            .navigationTitle("Now Playing").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { dismiss() } } }
            .onChange(of:playback.audio.elapsed) { _, value in if !dragging { position = value } }
            .task(id:playback.current?.id) { position = playback.audio.elapsed; favorite = songModel()?.favorite ?? false }
        }
    }
    private func songModel()->Song? {
        guard let id = playback.current?.id else { return nil }
        var q = FetchDescriptor<Song>(predicate:#Predicate { $0.id == id }); q.fetchLimit = 1
        return try? context.fetch(q).first
    }
    private func changeFavorite() {
        guard let song = songModel() else { return }
        song.favorite.toggle()
        do { try context.save(); favorite = song.favorite }
        catch { context.rollback(); playback.error = "Favorite could not be saved." }
    }
    static func time(_ value:Double)->String {
        guard value.isFinite, value >= 0 else { return "0:00" }
        let seconds = Int(value)
        return String(format:"%d:%02d",seconds/60,seconds%60)
    }
}

struct QueueView: View {
    @Environment(PlaybackController.self) private var playback
    var body: some View {
        List(playback.queue.tracks) { track in
            Button { playback.choose(track.id) } label: {
                HStack {
                    CoverView(artwork:track.artwork,size:40)
                    VStack(alignment:.leading) { Text(track.title); Text(track.artist).font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    if track.id == playback.current?.id { Image(systemName:"waveform") }
                }
            }.buttonStyle(.plain)
        }.soundlySurface().navigationTitle("Queue")
    }
}

struct SystemRoutePicker: UIViewRepresentable {
    func makeUIView(context:Context)->AVRoutePickerView { AVRoutePickerView() }
    func updateUIView(_ view:AVRoutePickerView,context:Context) {}
}
