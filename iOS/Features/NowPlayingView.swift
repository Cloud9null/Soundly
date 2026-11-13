import SwiftUI
import SwiftData
import AVFoundation
import AVKit
import MediaPlayer

struct NowPlayingView: View {
    @Environment(PlaybackController.self) private var playback
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.soundlySurface) private var surface
    @State private var position = 0.0
    @State private var dragging = false
    @State private var favorite = false
    @State private var quality = false
    @State private var queue = false
    @State private var artwork = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing:0) {
                    Button { artwork = true } label: {
                        CoverView(artwork:playback.current?.artwork,size:coverSize(geometry.size),cornerRadius:12)
                            .shadow(color:.black.opacity(0.18),radius:24,y:14)
                    }.buttonStyle(.plain).accessibilityLabel("View full-screen artwork")
                        .accessibilityIdentifier("expandArtwork").disabled(playback.current == nil)
                        .padding(.bottom,22)
                    trackInformation
                    progress.padding(.top,16)
                    transport.padding(.top,12)
                    HStack(spacing:12) {
                        Image(systemName:"speaker.fill")
                        SystemVolumeControl().frame(height:32).accessibilityLabel("System volume")
                        Image(systemName:"speaker.wave.3.fill")
                    }.font(.caption).foregroundStyle(.secondary).padding(.top,10)
                    if let error = playback.error { Text(error).font(.footnote).foregroundStyle(.red).padding(.top,12) }
                }.frame(maxWidth:520).padding(.horizontal,28).padding(.vertical,12)
                    .frame(maxWidth:.infinity,minHeight:geometry.size.height,alignment:.center)
            }.scrollIndicators(.hidden)
        }
        .background { ambient }
        .safeAreaInset(edge:.top,spacing:0) { header }
        .safeAreaInset(edge:.bottom,spacing:0) { footer }
        .sheet(isPresented:$quality) {
            NavigationStack {
                SignalPathView().toolbar {
                    ToolbarItem(placement:.confirmationAction) {
                        Button("Done") { quality = false }.accessibilityIdentifier("closeQuality")
                    }
                }
            }.presentationDetents([.medium,.large]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented:$queue) {
            NavigationStack {
                QueueView().toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { queue = false } } }
            }.presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented:$artwork) { ArtworkFullscreen(artwork:playback.current?.artwork) }
        .onChange(of:playback.audio.elapsed) { _, value in if !dragging { position = value } }
        .task(id:playback.current?.id) { position = playback.audio.elapsed; favorite = songModel()?.favorite ?? false }
    }
    private func coverSize(_ size:CGSize)->CGFloat { max(120,min(min(size.width-56,max(120,size.height-330)),440)) }
    private var ambient:some View {
        GeometryReader { geometry in
            ZStack {
                surface
                if let key = playback.current?.artwork, !reduceTransparency {
                    CoverView(artwork:key,size:max(geometry.size.width,geometry.size.height),cornerRadius:0)
                        .blur(radius:70).opacity(colorScheme == .dark ? 0.45 : 0.16)
                    (colorScheme == .dark ? Color.black.opacity(0.28) : Color.white.opacity(0.48))
                }
            }.frame(width:geometry.size.width,height:geometry.size.height).clipped()
        }.ignoresSafeArea()
    }
    private var header:some View {
        HStack {
            Button { dismiss() } label: { Image(systemName:"chevron.down").font(.title3.weight(.semibold)).frame(width:44,height:44) }
                .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Done").accessibilityIdentifier("nowPlayingDone")
            Spacer()
            VStack(spacing:2) {
                Text("NOW PLAYING").font(.caption2.weight(.semibold)).tracking(1.8)
                Text(playback.queue.positionLabel).font(.caption2.monospacedDigit()).accessibilityIdentifier("queuePosition")
            }.foregroundStyle(.secondary)
            Spacer()
            Color.clear.frame(width:44,height:44).accessibilityHidden(true)
        }.padding(.horizontal,16).padding(.top,4)
    }
    private var trackInformation:some View {
        VStack(alignment:.leading,spacing:8) {
            HStack(alignment:.center,spacing:14) {
                VStack(alignment:.leading,spacing:4) {
                    Text(playback.current?.title ?? "Nothing playing").font(.title2.bold()).lineLimit(2)
                    Text(playback.current.map { $0.artist + " · " + $0.album } ?? "Choose a song from your library to begin.")
                        .font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                }.frame(maxWidth:.infinity,alignment:.leading)
                if playback.current != nil {
                    iconButton(favorite ? "Unfavorite" : "Favorite",symbol:favorite ? "star.fill" : "star",id:"favoriteToggle",active:favorite) { changeFavorite() }
                }
            }
            Button { quality = true } label: {
                HStack(spacing:6) {
                    Image(systemName:"waveform")
                    Text(playback.current?.sourceQuality ?? "Audio quality").lineLimit(1).minimumScaleFactor(0.8)
                    Image(systemName:"chevron.down").font(.system(size:9,weight:.semibold))
                }.font(.caption.weight(.medium)).padding(.vertical,7).padding(.horizontal,10)
                    .background(.primary.opacity(0.06),in:Capsule())
            }.buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Audio quality and signal path")
                .accessibilityValue(playback.current?.sourceQuality ?? "No source selected")
                .accessibilityIdentifier("audioQualityButton")
        }
    }
    private var progress:some View {
        VStack(spacing:4) {
            Slider(value:$position,in:0...max(1,playback.audio.duration)) { editing in
                dragging = editing; if !editing { playback.seek(position) }
            }.tint(.primary).accessibilityLabel("Playback position").disabled(playback.busy || playback.current == nil)
            HStack {
                Text(Self.time(position)); Spacer()
                Text("−"+Self.time(max(0,playback.audio.duration-position)))
            }.font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
        }
    }
    private var transport:some View {
        HStack {
            Spacer()
            Button("Previous",systemImage:"backward.end.fill") { playback.previous() }
                .font(.system(size:28,weight:.medium)).frame(width:64,height:64)
            Spacer()
            Button(playback.audio.playing ? "Pause" : "Play",systemImage:playback.audio.playing ? "pause.fill" : "play.fill") { playback.toggle() }
                .font(.system(size:42,weight:.medium)).frame(width:80,height:68).accessibilityIdentifier("transportToggle")
            Spacer()
            Button("Next",systemImage:"forward.end.fill") { playback.next() }
                .font(.system(size:28,weight:.medium)).frame(width:64,height:64)
            Spacer()
        }.labelStyle(.iconOnly).buttonStyle(.plain).foregroundStyle(.primary)
            .disabled(playback.busy || playback.current == nil)
    }
    private var footer:some View {
        HStack {
            iconButton("Shuffle",symbol:"shuffle",id:"shuffleButton",active:playback.queue.shuffle) { playback.toggleShuffle() }
                .accessibilityValue(playback.queue.shuffle ? "On" : "Off")
            Spacer()
            iconButton("Repeat",symbol:playback.queue.repeatMode == .one ? "repeat.1" : "repeat",id:"repeatButton",active:playback.queue.repeatMode != .off) { playback.cycleRepeat() }
                .accessibilityValue(playback.queue.repeatMode.rawValue)
            Spacer()
            SystemRoutePicker().frame(width:44,height:44).accessibilityLabel("Choose audio output")
            Spacer()
            iconButton("Queue",symbol:"list.bullet",id:"openQueue") { queue = true }
            Spacer()
            Menu {
                Button("Audio quality",systemImage:"waveform") { quality = true }
                Button("Stop playback",systemImage:"stop") { playback.stop() }
                    .disabled(playback.current == nil)
            } label: { Image(systemName:"ellipsis").font(.title3).frame(width:44,height:44) }
                .accessibilityLabel("More playback options").accessibilityIdentifier("playbackMenu")
        }.padding(.horizontal,28).padding(.vertical,8).foregroundStyle(.primary)
    }
    private func iconButton(_ title:String,symbol:String,id:String,active:Bool = false,action:@escaping()->Void)->some View {
        Button(action:action) {
            Image(systemName:symbol).font(.system(size:20,weight:.medium)).frame(width:44,height:44)
                .background(active ? Color.accentColor.opacity(0.13) : .clear,in:RoundedRectangle(cornerRadius:12))
        }.buttonStyle(.plain).foregroundStyle(active ? Color.accentColor : Color.primary)
            .accessibilityLabel(title).accessibilityIdentifier(id)
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
        let seconds = Int(value); return String(format:"%d:%02d",seconds/60,seconds%60)
    }
}

struct ArtworkFullscreen:View {
    let artwork:String?
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                CoverView(artwork:artwork,size:min(geometry.size.width,geometry.size.height),cornerRadius:0)
                    .frame(maxWidth:.infinity,maxHeight:.infinity)
                VStack { HStack { Spacer(); Button { dismiss() } label: { Image(systemName:"xmark").frame(width:44,height:44).glassEffect() }.accessibilityLabel("Close artwork").accessibilityIdentifier("closeArtwork") }; Spacer() }.padding(20)
            }
        }.background(.black).preferredColorScheme(.dark).accessibilityIdentifier("fullScreenArtwork")
    }
}

struct QueueView: View {
    @Environment(PlaybackController.self) private var playback
    var body: some View {
        List {
            Section {
                ForEach(Array(playback.queue.tracks.enumerated()),id:\.element.id) { index, track in
                    Button { playback.choose(track.id) } label: {
                        HStack(spacing:12) {
                            Text("\(index+1)").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(minWidth:24)
                            CoverView(artwork:track.artwork,size:44)
                            VStack(alignment:.leading) { Text(track.title).lineLimit(1); Text(track.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                            Spacer()
                            if track.id == playback.current?.id { Image(systemName:"waveform").foregroundStyle(.tint) }
                        }
                    }.buttonStyle(.plain)
                }
            } header: { Text("\(playback.queue.tracks.count) songs · "+playback.queue.positionLabel) }
        }.soundlySurface().navigationTitle("Queue")
    }
}

struct SystemRoutePicker: UIViewRepresentable {
    func makeUIView(context:Context)->AVRoutePickerView { let view = AVRoutePickerView(); view.tintColor = .label; return view }
    func updateUIView(_ view:AVRoutePickerView,context:Context) {}
}

struct SystemVolumeControl:UIViewRepresentable {
    func makeUIView(context:Context)->MPVolumeView {
        let view = MPVolumeView(frame:.zero); view.showsRouteButton = false; view.tintColor = .label; return view
    }
    func updateUIView(_ view:MPVolumeView,context:Context) {}
}
