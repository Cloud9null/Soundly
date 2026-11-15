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
struct PlaylistsView:View {
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
    @State private var incomingName = ""
    @State private var exportType:UTType = .json
    @State private var exportName = "Soundly-playlists"
    var body:some View {
        List {
            Section("New playlist") {
                TextField("Playlist name",text:$name).focused($naming).accessibilityIdentifier("playlistName")
                Button("Create playlist") {
                    let title = name.trimmingCharacters(in:.whitespacesAndNewlines)
                    guard !title.isEmpty,title.count <= 200 else { return }
                    lists.append(LocalPlaylist(name:title)); name = ""; naming = false; save()
                }.accessibilityIdentifier("createPlaylist")
            }
            Section {
                ForEach($lists) { $list in
                    NavigationLink {
                        List {
                            TextField("Name",text:$list.name).onSubmit { save() }
                            Section("Tracks · \(list.hashes.count)") {
                                ForEach(Array(list.hashes.enumerated()),id:\.offset) { index,hash in
                                    if let song = songs.first(where:{$0.fileHash == hash}) {
                                        Button(song.title) { playback.play(song,within:resolved(list)) }.disabled(!song.available)
                                            .contextMenu {
                                                if let url = musicURL(song) { ShareLink(item:url) { Label("Share music file",systemImage:"square.and.arrow.up") } }
                                            }
                                    } else { Text("Unavailable track").foregroundStyle(.secondary) }
                                }.onDelete { list.hashes.remove(atOffsets:$0); save() }
                                    .onMove { list.hashes.move(fromOffsets:$0,toOffset:$1); save() }
                            }
                            if let entries = list.unresolved,!entries.isEmpty {
                                Section("Unmatched references · \(entries.count)") {
                                    ForEach(Array(entries.enumerated()),id:\.offset) { _,entry in
                                        VStack(alignment:.leading) {
                                            Text(entry.title ?? entry.reference)
                                            Text(entry.reference).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }.onDelete { offsets in list.unresolved?.remove(atOffsets:offsets);save() }
                                    Button("Retry matching") { retryMatching(list) }.disabled(busy)
                                }
                            }
                            Section {
                                Button("Export M3U8",systemImage:"square.and.arrow.up") { exportM3U(list) }
                            } footer: { Text("Playlist only. To use elsewhere, share music files from the track context menus and place them beside this playlist, preserving filenames. Unmatched references are retained separately and exported after matched tracks.") }
                            Section("Add from library") {
                                ForEach(songs) { song in
                                    Button { if !list.hashes.contains(song.fileHash) { list.hashes.append(song.fileHash); save() } } label: {
                                        Label(song.title,systemImage:list.hashes.contains(song.fileHash) ? "checkmark" : "plus")
                                    }
                                }
                            }
                        }.navigationTitle(list.name).toolbar { EditButton() }.soundlySurface()
                            .onDisappear { save() }
                    } label: { Label(list.name,systemImage:"music.note.list") }
                }.onDelete { lists.remove(atOffsets:$0); save() }
            }
            Section("Portable playlists") {
                Button("Export playlists") {
                    do { document = PlaylistDocument(data:try JSONEncoder().encode(PlaylistExchange(playlists:lists))); exportType = .json;exportName = "Soundly-playlists";exporting = true }
                    catch { message = error.localizedDescription }
                }
                Button("Import playlists") { importing = true }.disabled(busy)
                if busy { ProgressView("Reading playlist…") }
                Text("Import Soundly JSON or local M3U/M3U8, then review matches before importing. Remote streams are not fetched. Music must already be in your library. JSON exchanges all playlists; M3U8 export is available inside each playlist. Unmatched references are retained for later matching.").font(.footnote)
                if let message { Text(message).font(.footnote) }
            }
        }.navigationTitle("Playlists").soundlySurface().disabled(busy)
            .onAppear { if let value = try? PlaylistExchange.decode(stored) { lists = value.playlists } }
            .fileExporter(isPresented:$exporting,document:document,contentType:exportType,defaultFilename:exportName) { result in
                if case .failure(let error) = result,(error as NSError).code != NSUserCancelledError { message = "Export could not finish. Your playlists were preserved." }
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
                    let additions = exchange.playlists.map { item in var item = item;item.id = UUID();return item }
                    if save(candidate:lists+additions) { message = "Imported \(additions.count) playlists. Music files are not included." }
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
        } catch { message = "Could not export this playlist. Saved playlists were preserved." }
    }
    private func resolved(_ list:LocalPlaylist)->[Song] { list.hashes.compactMap { hash in songs.first { $0.fileHash == hash } } }
    @discardableResult private func save(candidate:[LocalPlaylist]? = nil)->Bool {
        do { let bytes = try JSONEncoder().encode(PlaylistExchange(playlists:candidate ?? lists)); _ = try PlaylistExchange.decode(bytes); stored = bytes; if let candidate { lists = candidate };return true }
        catch { if candidate == nil,let previous = try? PlaylistExchange.decode(stored) { lists = previous.playlists };message = "Playlists could not be saved. Previous saved data was preserved."; return false }
    }
}
