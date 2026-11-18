import SwiftUI
import SwiftData
import AVFoundation
import AVKit

struct NowPlayingView: View {
    @Environment(PlaybackController.self) private var playback
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.soundlySurface) private var surface
    @AppStorage("visualizerStyle") private var visualizerStyle = "Flow"
    @AppStorage("playerBackdrop") private var backdrop = "Artwork"
    @State private var position = 0.0
    @State private var dragging = false
    @State private var favorite = false
    @State private var quality = false
    @State private var lyrics = false
    @State private var visualizerSettings = false
    @State private var queue = false
    @State private var artwork = false
    @State private var playlistSong: Song?

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing:0) {
                    Button { artwork = true } label: {
                        CoverView(artwork:playback.current?.artwork,size:coverSize(geometry.size),cornerRadius:20,fitArtwork:true)
                            .fixedSize()
                            .shadow(color:.black.opacity(0.18),radius:24,y:14)
                    }.buttonStyle(.plain).frame(width:coverSize(geometry.size),height:coverSize(geometry.size))
                        .accessibilityLabel("View full-screen artwork")
                        .accessibilityIdentifier("expandArtwork").disabled(playback.current == nil)
                        .padding(.bottom,22)
                    trackInformation
                    VStack(spacing:14) {
                        progress
                        transport
                    }.padding(.vertical,12)
                        .accessibilityElement(children:.contain).accessibilityIdentifier("playbackDeck").padding(.top,18)
                    if let error = playback.error { Text(error).font(.footnote).foregroundStyle(.red).padding(.top,12) }
                }.frame(maxWidth:520).padding(.horizontal,24).padding(.top,18).padding(.bottom,16)
                    .frame(maxWidth:.infinity,minHeight:geometry.size.height,alignment:.top)
            }.scrollIndicators(.hidden).clipped()
        }
        .background { ambient }
        .safeAreaInset(edge:.top,spacing:0) { header }
        .safeAreaInset(edge:.bottom,spacing:0) { footer }
        .sheet(isPresented:$visualizerSettings) {
            NavigationStack { VisualizerSettingsView().toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { visualizerSettings = false } } } }
        }
        .sheet(item: $playlistSong) { song in AddToPlaylistView(song: song) }
        .sheet(isPresented:$lyrics) {
            NavigationStack { LyricsView().toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { lyrics = false } } } }
        }
        .sheet(isPresented:$quality) {
            NavigationStack {
                SignalPathView().toolbar {
                    ToolbarItem(placement:.confirmationAction) {
                        Button("Done") { quality = false }.accessibilityIdentifier("closeQuality")
                    }
                }
            }.presentationDetents([.large]).presentationDragIndicator(.visible)
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
    private func coverSize(_ size:CGSize)->CGFloat {
        if textSize.isAccessibilitySize { return min(180,max(100,size.width*0.45)) }
        // Reserve room for a two-line title and accessible controls; the artwork remains square.
        return max(120,min(min(size.width-48,max(120,size.height-340)),460))
    }
    private var ambient:some View {
        GeometryReader { geometry in
            ZStack {
                surface
                if backdrop == "Artwork",let key = playback.current?.artwork, !reduceTransparency {
                    CoverView(artwork:key,size:max(geometry.size.width,geometry.size.height),cornerRadius:0)
                        .blur(radius:70).opacity(colorScheme == .dark ? 0.45 : 0.16)
                    (colorScheme == .dark ? Color.black.opacity(0.28) : Color.white.opacity(0.48))
                } else if let colors = PlayerBackdrop.colors(backdrop), !reduceTransparency {
                    LinearGradient(colors:colors.map { $0.opacity(colorScheme == .dark ? 0.5 : 0.18) },startPoint:.topLeading,endPoint:.bottomTrailing)
                    RadialGradient(colors:[Color.accentColor.opacity(0.16),.clear],center:.topTrailing,startRadius:10,endRadius:500)
                }
            }.frame(width:geometry.size.width,height:geometry.size.height).clipped()
        }.ignoresSafeArea()
    }
    private var header:some View {
        HStack {
            Button { dismiss() } label: { Image(systemName:"chevron.down").font(.title3.weight(.semibold)).frame(width:44,height:44).contentShape(Rectangle()).glassEffect(in:.circle) }
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
                        .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }.frame(maxWidth:.infinity,alignment:.leading)
                if playback.current != nil {
                    iconButton(favorite ? "Unfavorite" : "Favorite",symbol:favorite ? "star.fill" : "star",id:"favoriteToggle",active:favorite) { changeFavorite() }
                }
            }
            Button { quality = true } label: {
                HStack(spacing:6) {
                    Image(systemName:"waveform")
                    Text(qualityLabel).lineLimit(1).minimumScaleFactor(0.8)
                    Image(systemName:"chevron.down").font(.system(size:9,weight:.semibold))
                }.font(.caption.weight(.medium)).padding(.vertical,7).padding(.horizontal,10)
                    .glassEffect(in:.capsule)
            }.buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Audio quality and signal path")
                .accessibilityValue(qualityLabel)
                .accessibilityIdentifier("audioQualityButton")
        }
    }
    private var qualityLabel: String {
        guard !playback.busy, let rate = playback.audio.signalPath.outputRate else { return sourceQuality }
        return sourceQuality + "  →  " + SignalPathView.rate(rate)
    }

    private var sourceQuality:String {
        let report = playback.audio.signalPath
        guard !playback.busy,playback.current != nil,let pcm = report.snapshot.source else {
            return playback.current?.sourceQuality ?? "Audio quality"
        }
        return report.source.codec+" · "+(pcm.bitDepth.map { "\($0)-bit · " } ?? "")+SignalPathView.rate(pcm.sampleRate)
    }
    private var progress:some View {
        VStack(spacing:6) {
            GeometryReader { geometry in
                let fraction = min(1,max(0,position/max(0.001,playback.audio.duration)))
                ZStack(alignment:.leading) {
                    SourceVisualizer(progress:fraction, allowMotion: !dragging && !quality && !lyrics && !visualizerSettings && !queue && !artwork && playlistSong == nil)
                    if visualizerStyle != "Flow" || dragging {
                        Capsule().fill(Color.primary.opacity(dragging ? 0.95 : 0.7))
                            .frame(width:dragging ? 3 : 1.5,height:dragging ? 44 : 32)
                            .offset(x:max(0,min(geometry.size.width-3,geometry.size.width*fraction-1.5)))
                            .animation(.easeOut(duration:0.16),value:dragging)
                    }
                }.frame(maxHeight:.infinity).contentShape(Rectangle())
                    .animation(dragging ? nil : .linear(duration:0.5),value:position)
                    .gesture(DragGesture(minimumDistance:0).onChanged { value in
                        guard playback.current != nil,!playback.busy else { return };dragging = true
                        position = min(max(0,value.location.x/max(1,geometry.size.width)),1)*max(0,playback.audio.duration)
                    }.onEnded { _ in
                        guard dragging else { return };playback.seek(position);dragging = false
                    })
            }.frame(height:44).accessibilityElement(children:.ignore)
                .accessibilityLabel("Playback position").accessibilityValue(Self.time(position)+" of "+Self.time(playback.audio.duration))
                .accessibilityIdentifier("waveformScrubber")
                .accessibilityAdjustableAction { direction in
                    guard playback.current != nil,!playback.busy else { return }
                    let step:Double
                    switch direction { case .increment: step = 5; case .decrement: step = -5; @unknown default: return }
                    position = max(0,min(playback.audio.duration,position+step));playback.seek(position)
                }
            HStack {
                Text(Self.time(position));Spacer();Text("−"+Self.time(max(0,playback.audio.duration-position)))
            }.font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
        }
    }
    private var transport:some View {
        HStack {
            Spacer()
            Button { playback.previous() } label: { Image(systemName:"backward.end.fill").font(.system(size:25,weight:.semibold)).frame(width:64,height:64).contentShape(Rectangle()) }.accessibilityLabel("Previous")
            Spacer()
            Button { playback.toggle() } label: { Image(systemName:playback.audio.playing ? "pause.fill" : "play.fill").font(.system(size:32,weight:.semibold)).offset(x:playback.audio.playing ? 0 : 2).frame(width:64,height:64).contentShape(Circle()) }.accessibilityLabel(playback.audio.playing ? "Pause" : "Play").accessibilityIdentifier("transportToggle")
            Spacer()
            Button { playback.next() } label: { Image(systemName:"forward.end.fill").font(.system(size:25,weight:.semibold)).frame(width:64,height:64).contentShape(Rectangle()) }.accessibilityLabel("Next")
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
            iconButton("Lyrics", symbol: "quote.bubble", id: "openLyrics", active: lyrics) { lyrics = true }
                .disabled(playback.current == nil)
            Spacer()
            SystemRoutePicker().frame(width:44,height:44).accessibilityLabel("Choose audio output")
            Spacer()
            iconButton("Queue",symbol:"list.bullet",id:"openQueue") { queue = true }
            Spacer()
            Menu {
                Button("Player appearance",systemImage:"paintpalette") { visualizerSettings = true }
                Button("Add to playlist", systemImage: "text.badge.plus") { playlistSong = songModel() }
                    .disabled(playback.current == nil)
                Button("Audio quality",systemImage:"waveform") { quality = true }
                Button("Stop playback",systemImage:"stop") { playback.stop() }
                    .disabled(playback.current == nil)
            } label: { Image(systemName:"ellipsis").font(.title3).frame(width:44,height:44) }
                .accessibilityLabel("More playback options").accessibilityIdentifier("playbackMenu")
        }.padding(.horizontal,8).padding(.vertical,8).foregroundStyle(.primary)
            .glassEffect(in:.capsule).padding(.horizontal,20).padding(.bottom,8)
    }
    private func iconButton(_ title:String,symbol:String,id:String,active:Bool = false,action:@escaping()->Void)->some View {
        Button(action:action) {
            Image(systemName:symbol).font(.system(size:20,weight:.medium)).frame(width:44,height:44)
                .background(active ? Color.accentColor.opacity(0.13) : .clear,in:Circle()).contentShape(Rectangle())
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
                VStack { HStack { Spacer(); Button { dismiss() } label: { Image(systemName:"xmark").frame(width:44,height:44).contentShape(Rectangle()).glassEffect() }.buttonStyle(.plain).foregroundStyle(.white).accessibilityLabel("Close artwork").accessibilityIdentifier("closeArtwork") }; Spacer() }.padding(20)
            }
        }.background(.black).preferredColorScheme(.dark)
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
