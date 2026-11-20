import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LocalPlaylist:Identifiable,Codable,Equatable,Sendable {
    var id = UUID()
    var name:String
    var hashes:[String] = []
    var unresolved:[M3UEntry]? = nil
}
struct PlaylistDocument:FileDocument {
    static var readableContentTypes:[UTType] { [.json,.m3uPlaylist] }
    var data:Data
    init(data:Data) { self.data = data }
    init(configuration:ReadConfiguration)throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration:WriteConfiguration)throws->FileWrapper { FileWrapper(regularFileWithContents:data) }
}
struct PlaylistExchange:Codable,Sendable {
    var soundlyVersion = 1
    var playlists:[LocalPlaylist]
    static func saved(_ bytes: Data) throws -> [LocalPlaylist] {
        if bytes.isEmpty { return [] }
        return try decode(bytes).playlists
    }

    static func encode(_ lists: [LocalPlaylist]) throws -> Data {
        let bytes = try JSONEncoder().encode(Self(playlists: lists))
        _ = try decode(bytes)
        return bytes
    }

    static func decode(_ bytes:Data)throws->Self {
        guard bytes.count <= 2*1024*1024 else { throw CocoaError(.fileReadTooLarge) }
        let value = try JSONDecoder().decode(Self.self,from:bytes)
        guard value.soundlyVersion == 1,value.playlists.count <= 1000,Set(value.playlists.map(\.id)).count == value.playlists.count,
              value.playlists.allSatisfy({ !$0.name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && $0.name.count <= 200 && $0.hashes.count+($0.unresolved?.count ?? 0) <= 20000 && ($0.unresolved ?? []).allSatisfy(M3U.valid) && Set($0.hashes).count == $0.hashes.count }) else { throw CocoaError(.fileReadCorruptFile) }
        return value
    }
}
struct PendingM3U:Identifiable {
    let id = UUID()
    let result:M3UResolution
    let remote:Int
    let invalid:Int
}
enum PlaylistEntryPoint: Hashable {
    case create, importFile
}

struct PlaylistsView:View {
    var entryPoint: PlaylistEntryPoint? = nil
    @State private var didOpenEntryPoint = false
    @Query(sort:\Song.title) private var songs:[Song]
    @Environment(PlaybackController.self) private var playback
    @AppStorage("localPlaylists") private var stored = Data()
    @State private var lists:[LocalPlaylist] = []
    @State private var name = ""
    @FocusState private var naming:Bool
    @State private var importing = false
    @State private var exporting = false
    @State private var document = PlaylistDocument(data:Data())
    @State private var message:String?
    @State private var busy = false
    @State private var pending:PendingM3U?
    @State private var pendingJSON: PlaylistExchange?
    @State private var addingTracks: LocalPlaylist?
    @State private var renameID: UUID?
    @State private var proposedName = ""
    @State private var renaming = false
    @State private var detailMessage: String?
    @State private var incomingName = ""
    @State private var exportType:UTType = .json
    @State private var exportName = "Soundly-playlists"
    var body:some View {
        let catalogTracks = tracksByHash
        List {
            Section("New playlist") {
                TextField("Playlist name",text:$name).focused($naming).accessibilityIdentifier("playlistName")
                Button("Create playlist") {
                    let title = name.trimmingCharacters(in:.whitespacesAndNewlines)
                    guard !title.isEmpty,title.count <= 200 else { return }
                    if save(candidate: lists + [LocalPlaylist(name: title)]) {
                        name = ""
                        naming = false
                    }
                }.accessibilityIdentifier("createPlaylist")
            }
            Section {
                ForEach($lists) { $list in
                    NavigationLink {
                        playlistDetail($list)
                    } label: {
                        HStack(spacing: 12) {
                            CoverView(artwork: artwork(for: list, in: catalogTracks), size: 58)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(list.name).font(.headline).foregroundStyle(.primary)
                                Text("\(list.hashes.count) tracks").font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 3).accessibilityElement(children: .combine).accessibilityLabel(list.name)
                    }.contextMenu {
                        Button("Duplicate playlist", systemImage: "plus.square.on.square") {
                            var copy = list
                            copy.id = UUID()
                            copy.name = String(list.name.prefix(193)) + " (Copy)"
                            _ = save(candidate: lists + [copy])
                        }
                    }
                }.onDelete { lists.remove(atOffsets:$0); save() }
            }
            Section("Portable playlists") {
                Button("Export playlists", systemImage: "square.and.arrow.up") {
                    exportJSON(lists, named: "Soundly-playlists")
                }.disabled(lists.isEmpty)
                Button("Import playlists") { importing = true }.disabled(busy)
                if busy { ProgressView("Reading playlist…") }
                Text("Import a Soundly JSON backup or an M3U/M3U8 playlist. Export all playlists here or export a single playlist from its detail.").font(.footnote)
                if let message { Text(message).font(.footnote) }
            }
        }.navigationTitle("Playlists").soundlySurface().disabled(busy)
            .onAppear { reload() }
            .task {
                guard !didOpenEntryPoint, let entryPoint else { return }
                // Allow the navigation transition to settle before focusing or presenting Files.
                do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                didOpenEntryPoint = true
                switch entryPoint {
                case .create: naming = true
                case .importFile: importing = true
                }
            }
            .onChange(of: stored) { _, _ in reload() }
            .sheet(isPresented: Binding(get: { pendingJSON != nil }, set: { if !$0 { pendingJSON = nil } })) {
                if let exchange = pendingJSON {
                    NavigationStack {
                        List {
                            ForEach(exchange.playlists) { list in
                                Label(list.name, systemImage: "music.note.list")
                            }
                            Text("Matching music already in your library will be available to play. Identical playlists are skipped.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }.navigationTitle("Review playlists").soundlySurface()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { pendingJSON = nil } }
                            ToolbarItem(placement: .confirmationAction) { Button("Import") { importJSON(exchange) } }
                        }
                    }
                }
            }
            .fileExporter(isPresented:$exporting,document:document,contentType:exportType,defaultFilename:exportName) { result in
                if case .failure(let error) = result, (error as NSError).code != NSUserCancelledError {
                    message = "Export could not finish. Your playlists were preserved."
                    detailMessage = message
                }
            }
            .fileImporter(isPresented:$importing,allowedContentTypes:[.json,.m3uPlaylist,.plainText,.data]) { result in importFile(result) }
            .sheet(item:$pending) { preview in
                NavigationStack {
                    List {
                        TextField("Playlist name",text:$incomingName)
                        LabeledContent("Matched tracks",value:"\(preview.result.hashes.count)")
                        LabeledContent("Unmatched references",value:"\(preview.result.unresolved.count)")
                        LabeledContent("Ambiguous matches",value:"\(preview.result.ambiguousCount)")
                        LabeledContent("Repeated tracks collapsed",value:"\(preview.result.duplicateCount)")
                        LabeledContent("Remote references skipped",value:"\(preview.remote)")
                        LabeledContent("Invalid references skipped",value:"\(preview.invalid)")
                        Text("Matches use exact Soundly hashes/filenames, then unique local metadata. Ambiguous or missing entries stay in a separate pending section and do not play. No external music file is opened or downloaded.").font(.footnote).foregroundStyle(.secondary)
                        ForEach(Array(preview.result.unresolved.prefix(100).enumerated()),id:\.offset) { _,entry in Text(entry.title ?? entry.reference).foregroundStyle(.secondary) }
                    }.navigationTitle("Review playlist").soundlySurface()
                    .toolbar {
                        ToolbarItem(placement:.cancellationAction) { Button("Cancel") { pending = nil } }
                        ToolbarItem(placement:.confirmationAction) {
                            Button("Import") {
                                let title = incomingName.trimmingCharacters(in:.whitespacesAndNewlines)
                                let item = LocalPlaylist(name:title,hashes:preview.result.hashes,unresolved:preview.result.unresolved.isEmpty ? nil : preview.result.unresolved)
                                if save(candidate:lists+[item]) { message = "Imported playlist: \(item.hashes.count) matched, \(item.unresolved?.count ?? 0) pending.";pending = nil }
                            }.disabled(incomingName.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || incomingName.count > 200 || (preview.result.hashes.isEmpty && preview.result.unresolved.isEmpty))
                        }
                    }
                }
            }
    }
    private func playlistDetail(_ binding: Binding<LocalPlaylist>) -> some View {
        let list = binding.wrappedValue
        return List {
            Section {
                HStack(spacing: 12) {
                    Button("Play", systemImage: "play.fill") { play(list, shuffled: false) }
                    Button("Shuffle", systemImage: "shuffle") { play(list, shuffled: true) }
                }
                .buttonStyle(.glass)
                .disabled(!resolved(list).contains(where: \.available))
                Button("Add songs", systemImage: "plus") { addingTracks = list }
                    .accessibilityIdentifier("playlistAddSongs")
            }
            let tracks = tracksByHash
            Section("Tracks · \(list.hashes.count)") {
                ForEach(Array(list.hashes.enumerated()),id:\.offset) { _,hash in
                    if let song = tracks[hash] {
                        Button {
                            playback.play(song, within: resolved(list))
                        } label: {
                            HStack(spacing: 12) {
                                PlaylistSongLabel(song: song)
                                Spacer(minLength: 0)
                                if playback.current?.id == song.id {
                                    Image(systemName: playback.audio.playing ? "waveform" : "pause.circle")
                                        .foregroundStyle(.tint).accessibilityHidden(true)
                                }
                            }.padding(.vertical, 4).contentShape(Rectangle())
                        }.buttonStyle(.plain).disabled(!song.available)
                            .accessibilityLabel(song.title)
                            .contextMenu {
                                if let url = musicURL(song) { ShareLink(item:url) { Label("Share music file",systemImage:"square.and.arrow.up") } }
                            }
                    } else { Text("Unavailable track").foregroundStyle(.secondary) }
                }.onDelete { binding.wrappedValue.hashes.remove(atOffsets:$0); save() }
                    .onMove { binding.wrappedValue.hashes.move(fromOffsets:$0,toOffset:$1); save() }
            }
            if let entries = list.unresolved,!entries.isEmpty {
                Section("Unmatched references · \(entries.count)") {
                    ForEach(Array(entries.enumerated()),id:\.offset) { _,entry in
                        VStack(alignment:.leading) {
                            Text(entry.title ?? entry.reference)
                            Text(entry.reference).font(.caption).foregroundStyle(.secondary)
                        }
                    }.onDelete { offsets in binding.wrappedValue.unresolved?.remove(atOffsets:offsets);save() }
                    Button("Retry matching") { retryMatching(list) }.disabled(busy)
                }
            }
            Section {
                Button("Export M3U8",systemImage:"square.and.arrow.up") { exportM3U(list) }
                Button("Export Soundly JSON", systemImage: "doc") { exportJSON([list], named: list.name) }
                if let detailMessage { Text(detailMessage).font(.footnote).foregroundStyle(.secondary) }
            } header: { Text("Export") } footer: { Text("Playlist only. To use elsewhere, share music files from the track context menus and place them beside this playlist, preserving filenames. Unmatched references are retained separately and exported after matched tracks.") }
        }.navigationTitle(list.name).toolbar {
            ToolbarItem(placement: .primaryAction) { EditButton() }
            ToolbarItem(placement: .secondaryAction) {
                Button("Rename playlist", systemImage: "pencil") {
                    proposedName = list.name
                    renameID = list.id
                    renaming = true
                }
            }
        }.soundlySurface()
            .alert("Rename playlist", isPresented: $renaming) {
                TextField("Playlist name", text: $proposedName)
                Button("Cancel", role: .cancel) { renameID = nil }
                Button("Save") { rename() }
                    .disabled(proposedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || proposedName.count > 200)
            }
            .sheet(item: $addingTracks) { list in
                PlaylistTrackPicker(songs: songs, existing: Set(list.hashes)) { hashes in
                    guard let index = lists.firstIndex(where: { $0.id == list.id }) else { return false }
                    var updated = lists
                    let currentHashes = Set(updated[index].hashes)
                    updated[index].hashes.append(contentsOf: hashes.filter { !currentHashes.contains($0) })
                    return save(candidate: updated)
                }
            }
    }

    private func artwork(for list: LocalPlaylist, in tracks: [String: Song]) -> String? {
        for hash in list.hashes {
            if let artwork = tracks[hash]?.artwork { return artwork }
        }
        return nil
    }

    private var catalog:[M3UCatalogItem] { songs.map { M3UCatalogItem(hash:$0.fileHash,filename:$0.filename,title:$0.title,artist:$0.artist) } }
    private func importFile(_ result:Result<URL,Error>) {
        guard case .success(let url) = result else { return }
        guard ["json","m3u","m3u8"].contains(url.pathExtension.lowercased()) else { message = "Choose a JSON, M3U or M3U8 playlist.";return }
        busy = true
        let records = catalog
        Task {
            defer { busy = false }
            do {
                let bytes = try await Task.detached {
                    let scoped = url.startAccessingSecurityScopedResource();defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    let file = try FileHandle(forReadingFrom:url);defer { try? file.close() }
                    return try file.read(upToCount:M3U.byteLimit+1) ?? Data()
                }.value
                let ext = url.pathExtension.lowercased()
                if ext == "json" {
                    let exchange = try await Task.detached { try PlaylistExchange.decode(bytes) }.value
                    pendingJSON = exchange
                } else if ext == "m3u" || ext == "m3u8" {
                    let result = try await Task.detached {
                        let parsed = try M3U.parse(bytes,strictUTF8:ext == "m3u8")
                        return (M3U.resolve(parsed.entries,catalog:records),parsed.remoteCount,parsed.invalidCount)
                    }.value
                    incomingName = String(url.deletingPathExtension().lastPathComponent.prefix(200))
                    pending = PendingM3U(result:result.0,remote:result.1,invalid:result.2)
                } else { message = "Choose a JSON, M3U or M3U8 playlist." }
            } catch { message = "Import failed. Saved playlists were preserved. Use a local playlist up to 2 MiB and 20,000 references; HLS/streaming lists are unsupported." }
        }
    }
    private func musicURL(_ song:Song)->URL? {
        guard song.available else { return nil }
        return try? PrivateMusicFile.url(song.filename,in:LibraryPaths.directory("Music"))
    }
    private func retryMatching(_ list:LocalPlaylist) {
        guard !busy else { return };busy = true
        let entries = list.unresolved ?? [];let records = catalog;let id = list.id
        Task {
            defer { busy = false }
            let result = await Task.detached { M3U.resolve(entries,catalog:records) }.value
            guard let index = lists.firstIndex(where:{$0.id == id}) else { return }
            var candidate = lists
            let existing = Set(candidate[index].hashes)
            candidate[index].hashes.append(contentsOf:result.hashes.filter { !existing.contains($0) })
            candidate[index].unresolved = result.unresolved.isEmpty ? nil : result.unresolved
            _ = save(candidate:candidate)
        }
    }
    private func exportM3U(_ list:LocalPlaylist) {
        let tracks = Dictionary(songs.map { ($0.fileHash,$0) },uniquingKeysWith:{ first,_ in first })
        let entries = list.hashes.map { hash -> M3UEntry in
            guard let song = tracks[hash] else { return M3UEntry(reference:hash+".missing",sha256:M3U.validHash(hash) ? hash : nil) }
            return M3UEntry(reference:song.filename,title:song.artist+" - "+song.title,duration:song.duration,sha256:M3U.validHash(hash) ? hash : nil)
        }+(list.unresolved ?? [])
        do {
            document = PlaylistDocument(data:try M3U.encode(entries));exportType = .m3uPlaylist
            let safe = list.name.components(separatedBy:CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator:"-")
            exportName = String((safe.isEmpty ? "Soundly-playlist" : safe).prefix(80))+".m3u8";exporting = true
        } catch { detailMessage = "Could not export this playlist." }
    }

    private var tracksByHash: [String: Song] {
        Dictionary(songs.map { ($0.fileHash, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func resolved(_ list: LocalPlaylist) -> [Song] {
        let tracks = tracksByHash
        return list.hashes.compactMap { tracks[$0] }
    }

    private func play(_ list: LocalPlaylist, shuffled: Bool) {
        let available = resolved(list).filter(\.available)
        let ordered = shuffled ? available.shuffled() : available
        guard let first = ordered.first else { return }
        playback.play(first, within: ordered, shuffle: false)
    }

    private func rename() {
        defer { renameID = nil }
        guard let index = lists.firstIndex(where: { $0.id == renameID }) else { return }
        var updated = lists
        updated[index].name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = save(candidate: updated)
    }

    private func importJSON(_ exchange: PlaylistExchange) {
        var updated = lists
        for var list in exchange.playlists {
            guard !updated.contains(where: {
                $0.name == list.name && $0.hashes == list.hashes && ($0.unresolved ?? []) == (list.unresolved ?? [])
            }) else { continue }
            list.id = UUID()
            updated.append(list)
        }
        let added = updated.count - lists.count
        if save(candidate: updated) {
            pendingJSON = nil
            message = "Imported \(added) playlists. Skipped \(exchange.playlists.count - added) identical copies."
        }
    }

    private func exportJSON(_ lists: [LocalPlaylist], named name: String) {
        do {
            document = PlaylistDocument(data: try PlaylistExchange.encode(lists))
            exportType = .json
            let clean = name.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: "-")
            exportName = clean.isEmpty ? "Soundly-playlist" : String(clean.prefix(80))
            exporting = true
        } catch {
            detailMessage = "Could not export this playlist."
            message = "Could not export playlists."
        }
    }

    private func reload() {
        do { lists = try PlaylistExchange.saved(stored) }
        catch { message = "Saved playlists could not be read." }
    }

    @discardableResult private func save(candidate: [LocalPlaylist]? = nil) -> Bool {
        do {
            _ = try PlaylistExchange.saved(stored)
            let updated = candidate ?? lists
            stored = try PlaylistExchange.encode(updated)
            lists = updated
            detailMessage = nil
            return true
        } catch {
            if candidate == nil { reload() }
            let error = "Playlists could not be saved. Previous saved data was preserved."
            message = error
            detailMessage = error
            return false
        }
    }
}

private struct PlaylistTrackPicker: View {
    let songs: [Song]
    let existing: Set<String>
    let add: ([String]) -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var selected: [String] = []
    @State private var showError = false

    private var selectedHashes: Set<String> { Set(selected) }

    private var matches: [Song] {
        songs.filter { song in
            song.available && (search.isEmpty || [song.title, song.artist, song.album].contains {
                $0.localizedStandardContains(search)
            })
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if matches.isEmpty { ContentUnavailableView("No songs found", systemImage: "music.note") }
                let selection = selectedHashes
                ForEach(matches) { song in
                    let added = existing.contains(song.fileHash)
                    let checked = selection.contains(song.fileHash)
                    Button {
                        if checked { selected.removeAll { $0 == song.fileHash } }
                        else { selected.append(song.fileHash) }
                    } label: {
                        HStack {
                            PlaylistSongLabel(song: song, artworkSize: 36)
                            Spacer()
                            Image(systemName: added || checked ? "checkmark.circle.fill" : "circle").foregroundStyle(.tint)
                        }
                    }.disabled(added)
                    .accessibilityValue(added ? "Already in playlist" : checked ? "Selected" : "Not selected")
                }
            }.navigationTitle("Add songs").soundlySurface()
            .searchable(text: $search, prompt: "Songs, artists or albums")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(selected.isEmpty ? "Add" : "Add (\(selected.count))") {
                        if add(selected) { dismiss() } else { showError = true }
                    }.accessibilityIdentifier("addSelectedSongs").disabled(selected.isEmpty)
                }
            }
            .alert("Could not save playlist", isPresented: $showError) { Button("OK", role: .cancel) {} }
        }
    }
}

struct PlaylistSongLabel: View {
    let song: Song
    var artworkSize: CGFloat = 46

    var body: some View {
        HStack(spacing: 12) {
            CoverView(artwork: song.artwork, size: artworkSize)
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title).foregroundStyle(.primary).lineLimit(1)
                Text([song.artist, song.album].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                if !song.available {
                    Text("Local file missing").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct AddToPlaylistView: View {
    let song: Song
    @Environment(\.dismiss) private var dismiss
    @AppStorage("localPlaylists") private var stored = Data()
    @State private var name = ""
    @State private var search = ""
    @State private var message: String?
    private var lists: [LocalPlaylist] { (try? PlaylistExchange.saved(stored)) ?? [] }

    private var matches: [LocalPlaylist] {
        lists.filter { search.isEmpty || $0.name.localizedStandardContains(search) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    PlaylistSongLabel(song: song)
                }
                if !lists.isEmpty {
                    Section("Your playlists") {
                        if matches.isEmpty { Text("No matching playlists").foregroundStyle(.secondary) }
                        ForEach(matches) { list in
                            let alreadyAdded = list.hashes.contains(song.fileHash)
                            Button { add(to: list.id) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(list.name).foregroundStyle(.primary)
                                        Text(alreadyAdded ? "Already added" : "\(list.hashes.count) tracks")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: alreadyAdded ? "checkmark.circle.fill" : "plus.circle")
                                        .foregroundStyle(.tint).accessibilityHidden(true)
                                }
                            }.disabled(alreadyAdded)
                            .accessibilityLabel(list.name)
                            .accessibilityValue(alreadyAdded ? "Already added" : "")
                        }
                    }
                }
                Section("New playlist") {
                    TextField("Playlist name", text: $name)
                    Button("Create and add", systemImage: "plus") { add(to: nil) }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 200)
                }
                if let message { Text(message).font(.footnote).foregroundStyle(.secondary) }
            }.navigationTitle("Add to playlist").soundlySurface()
            .searchable(text: $search, prompt: "Find a playlist")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func add(to id: UUID?) {
        do {
            var updated = try PlaylistExchange.saved(stored)
            if let id {
                guard let index = updated.firstIndex(where: { $0.id == id }) else {
                    message = "This playlist is no longer available."
                    return
                }
                if !updated[index].hashes.contains(song.fileHash) { updated[index].hashes.append(song.fileHash) }
            } else {
                let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
                updated.append(LocalPlaylist(name: title, hashes: [song.fileHash]))
            }
            stored = try PlaylistExchange.encode(updated)
            dismiss()
        } catch {
            message = "Could not add this song. Your saved playlists were preserved."
        }
    }
}
