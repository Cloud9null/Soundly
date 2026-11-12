import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("theme") private var theme = SoundlyTheme.system.rawValue
    @State private var nowPlaying = false
    @State private var playback = PlaybackController()
    @Environment(\.modelContext) private var context
    @Query(sort:\Song.title) private var songs:[Song]
    private var selected: PlaybackTrack? { playback.current }
    @State private var importer = ImportController()
    private var appearance: SoundlyTheme { SoundlyTheme(rawValue: theme) ?? .system }
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") { NavigationStack { HomeView(select: select) } }
            Tab("Library", systemImage: "square.stack") { NavigationStack { LibraryView(select: select) } }
            Tab("Settings", systemImage: "slider.horizontal.3") { NavigationStack { SettingsView() } }
        }
        .environment(importer)
        .environment(playback)
        .environment(\.soundlySurface,appearance.surface)
        .task { playback.attach(context) }
        .tabViewBottomAccessory {
            HStack(spacing:12) {
                Button { nowPlaying = true } label: {
                    HStack(spacing:12) {
                        CoverView(artwork:selected?.artwork,size:36)
                        VStack(alignment:.leading) {
                            Text(selected?.title ?? "Your music awaits").font(.subheadline.weight(.semibold)).lineLimit(1)
                            Text(selected?.artist ?? "No track selected").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel(selected == nil ? "Open Now Playing. No track selected" : "Open Now Playing")
                if selected != nil {
                    Button(playback.audio.playing ? "Pause" : "Play",systemImage:playback.audio.playing ? "pause.fill" : "play.fill") { playback.toggle() }
                        .labelStyle(.iconOnly).frame(minWidth:44,minHeight:44)
                }
            }.padding(.horizontal).padding(.vertical,8)
        }
        .sheet(isPresented:$nowPlaying) {
            NowPlayingView().environment(playback).environment(\.soundlySurface,appearance.surface)
                .modelContainer(context.container).preferredColorScheme(appearance.scheme)
        }
        .tint(appearance.accent).preferredColorScheme(appearance.scheme)
        .background(appearance.surface)
        .sensoryFeedback(.selection,trigger:selected?.id)
        .alert("Playback",isPresented:Binding(get:{playback.error != nil && !nowPlaying},set:{ if !$0 { playback.error = nil } })) { Button("OK",role:.cancel) {} } message: { Text(playback.error ?? "") }
    }
    private func select(_ song: Song) { playback.play(song,within:songs); nowPlaying = true }
}

struct HomeView: View {
    @Query(sort:\Song.dateAdded,order:.reverse) private var songs:[Song]
    let select:(Song)->Void
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:28) {
                VStack(alignment:.leading,spacing:12) {
                    Text("SOUNDLY").font(.caption.weight(.bold)).tracking(4).foregroundStyle(.tint)
                    Text("A space for\nyour sound.").font(.largeTitle.bold())
                    Text("Your music. Your files. Your sound.").foregroundStyle(.secondary)
                    AddMusicButton()
                }.frame(maxWidth:.infinity,alignment:.leading).padding(24)
                    .background(.tint.opacity(0.08),in:RoundedRectangle(cornerRadius:28))
                if songs.isEmpty {
                    ContentUnavailableView("Make yourself at home",systemImage:"opticaldisc",description:Text("Import files or a folder to build your offline library."))
                } else {
                    section("Recently added",Array(songs.prefix(12)))
                    section("Favorite songs",Array(songs.filter(\.favorite).prefix(12)))
                    Button("Discover a random album",systemImage:"shuffle") {
                        if let song = songs.randomElement() { select(song) }
                    }.buttonStyle(.glass)
                }
                Label("Private by design · Offline by default",systemImage:"lock.shield").font(.footnote).foregroundStyle(.secondary)
                ImportStatusView()
            }.padding()
        }.soundlySurface().navigationTitle("Listen")
    }
    @ViewBuilder private func section(_ title:String,_ items:[Song])->some View {
        if !items.isEmpty {
            VStack(alignment:.leading,spacing:12) {
                Text(title).font(.title2.bold())
                ScrollView(.horizontal) {
                    HStack(alignment:.top,spacing:16) {
                        ForEach(items) { song in
                            Button { select(song) } label: {
                                VStack(alignment:.leading) {
                                    CoverView(artwork:song.artwork,size:140)
                                    Text(song.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                                    Text(song.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }.frame(width:140)
                            }.buttonStyle(.plain)
                        }
                    }
                }.scrollIndicators(.hidden)
            }
        }
    }
}

struct LibraryView: View {
    let select:(Song)->Void
    @State private var search = ""
    @State private var mode = "Songs"
    @State private var favorites = false
    @State private var newest = false
    var body: some View {
        VStack(spacing:0) {
            Picker("Browse by",selection:$mode) {
                ForEach(["Songs","Albums","Artists","Album Artists","Genres","Composers","Folders"],id:\.self) { Text($0) }
            }.pickerStyle(.menu).padding(.horizontal)
            SongResults(search:search,mode:mode,favorites:favorites,newest:newest,select:select)
            ImportStatusView().padding(.horizontal)
        }.soundlySurface().navigationTitle("Library").searchable(text:$search,prompt:"Songs, artists or albums")
        .toolbar {
            ToolbarItem(placement:.topBarLeading) {
                Menu("Filter",systemImage:"line.3.horizontal.decrease") {
                    Toggle("Favorites only",isOn:$favorites)
                    Toggle("Recently added first",isOn:$newest)
                }
            }
            ToolbarItem(placement:.topBarTrailing) { AddMusicButton() }
        }
    }
}

struct SongResults: View {
    @Environment(\.modelContext) private var context
    @Query private var songs:[Song]
    let mode:String
    let select:(Song)->Void
    @State private var saveError = false
    init(search:String,mode:String,favorites:Bool,newest:Bool,select:@escaping(Song)->Void) {
        self.mode = mode; self.select = select
        let predicate = #Predicate<Song> { song in
            (!favorites || song.favorite) && (search.isEmpty || song.title.localizedStandardContains(search) || song.artist.localizedStandardContains(search) || song.album.localizedStandardContains(search))
        }
        _songs = Query(filter:predicate,sort:newest ? [SortDescriptor(\Song.dateAdded,order:.reverse)] : [SortDescriptor(\Song.title)])
    }
    var body: some View {
        List {
            if songs.isEmpty { ContentUnavailableView.search(text:"your library") }
            if mode == "Songs" {
                ForEach(songs) { row($0) }
            } else {
                let groups = Dictionary(grouping:songs) { song in
                    switch mode { case "Albums": song.album + " — " + song.albumArtist
                    case "Artists": song.artist
                    case "Album Artists": song.albumArtist
                    case "Genres": song.genre.isEmpty ? "Unknown Genre" : song.genre
                    case "Composers": song.composer.isEmpty ? "Unknown Composer" : song.composer
                    default: song.originalFolder }
                }
                ForEach(groups.keys.sorted(),id:\.self) { group in
                    DisclosureGroup(group) { ForEach(groups[group] ?? []) { row($0) } }
                }
            }
        }.listStyle(.plain).soundlySurface()
        .alert("Could not save favorite",isPresented:$saveError) { Button("OK",role:.cancel) {} }
    }
    private func row(_ song:Song)->some View {
        Button { select(song) } label: {
            HStack(spacing:12) {
                CoverView(artwork:song.artwork)
                VStack(alignment:.leading,spacing:4) {
                    Text(song.title).foregroundStyle(.primary).lineLimit(1)
                    Text(song.artist + " · " + song.album).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Text(song.available ? song.quality : "Local file missing").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(); if song.favorite { Image(systemName:"heart.fill").foregroundStyle(.tint) }
            }.padding(.vertical,4)
        }.buttonStyle(.plain)
        .swipeActions { Button(song.favorite ? "Unfavorite" : "Favorite",systemImage:"heart") {
            song.favorite.toggle()
            do { try context.save() } catch { context.rollback(); saveError = true }
        }.tint(.pink) }
    }
}

struct AddMusicButton: View {
    @Environment(\.modelContext) private var context
    @Environment(ImportController.self) private var importer
    @State private var picker:Bool?
    var body: some View {
        Menu("Add Music",systemImage:"plus") {
            Button("Select files",systemImage:"doc") { picker = false }
            Button("Select folder",systemImage:"folder") { picker = true }
        }.disabled(importer.running)
        .sheet(isPresented:Binding(get:{picker != nil},set:{ if !$0 { picker = nil } })) {
            MusicDocumentPicker(folders:picker ?? false) { urls in
                picker = nil; importer.start(urls,container:context.container)
            }
        }
    }
}

struct ImportStatusView: View {
    @Environment(ImportController.self) private var importer
    var body: some View {
        if importer.running {
            HStack {
                ProgressView()
                Text("\(importer.state.processed) processed · \(importer.state.imported) imported").font(.caption)
                Button("Cancel") { importer.cancel() }
            }.padding(.vertical,8).accessibilityElement(children:.contain)
        } else if let report = importer.report {
            VStack(alignment:.leading) {
                Text(report).font(.caption).foregroundStyle(.secondary)
                if !importer.state.issues.isEmpty {
                    DisclosureGroup("Import errors (up to 20)") {
                        ForEach(Array(importer.state.issues.enumerated()),id:\.offset) { _, issue in Text(issue).font(.caption) }
                    }
                }
            }
        }
    }
}

struct SettingsView: View {
    @AppStorage("theme") private var theme = SoundlyTheme.system.rawValue
    @Environment(\.modelContext) private var context
    @Query private var songs:[Song]
    @State private var message:String?
    @State private var busy = false
    @Environment(PlaybackController.self) private var playback
    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme",selection:$theme) { ForEach(SoundlyTheme.allCases) { Text($0.name).tag($0.rawValue) } }.accessibilityIdentifier("themePicker")
            }
            Section("Library") {
                AddMusicButton()
                LabeledContent("Imported tracks",value:"\(songs.count)")
                LabeledContent("Music storage",value:ByteCountFormatter.string(fromByteCount:songs.reduce(0){$0+$1.fileSize},countStyle:.file))
                NavigationLink("Imported folders") {
                    List(Set(songs.map(\.originalFolder)).sorted(),id:\.self) { Text($0) }
                        .navigationTitle("Imported folders")
                        .safeAreaInset(edge:.bottom) { Text("These are private copies. External folders are not linked or monitored.").font(.footnote).padding().background(.regularMaterial) }
                }
                Button("Rescan local library") {
                    busy = true
                    let container = context.container
                    Task {
                        do {
                            let writer = await Task.detached { LibraryWriter(modelContainer:container) }.value
                            let missing = try await writer.rescan()
                            message = "\(missing) missing files. Records preserved."
                        } catch { message = "Rescan failed. Records preserved." }
                        busy = false
                    }
                }.disabled(busy)
                Button("Clear artwork cache") {
                    busy = true
                    let container = context.container
                    Task {
                        do {
                            let writer = await Task.detached { LibraryWriter(modelContainer:container) }.value
                            try await writer.clearArtwork()
                            ArtworkCache.images.removeAllObjects()
                            message = "Artwork cleared. Rescan to regenerate from your music files."
                        } catch { message = "Could not clear artwork cache." }
                        busy = false
                    }
                }.disabled(busy)
                if let message { Text(message).font(.footnote) }
                Text("Byte-identical imports are skipped automatically. Import sources are not uploaded or retained as external permissions.").font(.footnote).foregroundStyle(.secondary)
                ImportStatusView()
            }
            Section("Audio") {
                NavigationLink("Output and signal diagnostics") { AudioDiagnosticsView() }
                Text("Native-rate request · Unity application gain · No EQ, ReplayGain or crossfade").font(.footnote)
                Text("Gapless transitions are not yet implemented. Output is Not Bit-Verified.").font(.footnote)
            }
            Section("Privacy") {
                Label("No accounts, analytics or trackers",systemImage:"lock.shield")
                Text("Music stays on this device. No external artwork or metadata lookups. Imported music is excluded from device backups; keep your original files.").font(.footnote)
            }
            Section("About") {
                LabeledContent("Version",value:"0.3.0 (3)")
                Text("Built with Apple frameworks. No third-party runtime code.")
            }
        }.soundlySurface().navigationTitle("Settings")
    }
}
