import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LocalPlaylist:Identifiable,Codable,Equatable {
    var id = UUID()
    var name:String
    var hashes:[String] = []
}
struct PlaylistDocument:FileDocument {
    static var readableContentTypes:[UTType] { [.json] }
    var data:Data
    init(data:Data) { self.data = data }
    init(configuration:ReadConfiguration)throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration:WriteConfiguration)throws->FileWrapper { FileWrapper(regularFileWithContents:data) }
}
struct PlaylistExchange:Codable {
    var soundlyVersion = 1
    var playlists:[LocalPlaylist]
    static func decode(_ bytes:Data)throws->Self {
        guard bytes.count <= 2*1024*1024 else { throw CocoaError(.fileReadTooLarge) }
        let value = try JSONDecoder().decode(Self.self,from:bytes)
        guard value.soundlyVersion == 1,value.playlists.count <= 1000,
              value.playlists.allSatisfy({ !$0.name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && $0.name.count <= 200 && $0.hashes.count <= 20000 && Set($0.hashes).count == $0.hashes.count }) else { throw CocoaError(.fileReadCorruptFile) }
        return value
    }
}
struct PlaylistsView:View {
    @Query(sort:\Song.title) private var songs:[Song]
    @Environment(PlaybackController.self) private var playback
    @AppStorage("localPlaylists") private var stored = Data()
    @State private var lists:[LocalPlaylist] = []
    @State private var name = ""
    @State private var importing = false
    @State private var exporting = false
    @State private var document = PlaylistDocument(data:Data())
    @State private var message:String?
    var body:some View {
        List {
            Section("New playlist") {
                TextField("Playlist name",text:$name).accessibilityIdentifier("playlistName")
                Button("Create playlist") {
                    let title = name.trimmingCharacters(in:.whitespacesAndNewlines)
                    guard !title.isEmpty,title.count <= 200 else { return }
                    lists.append(LocalPlaylist(name:title)); name = ""; save()
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
                                        Button(song.title) { playback.play(song,within:resolved(list)) }
                                    } else { Text("Unavailable track").foregroundStyle(.secondary) }
                                }.onDelete { list.hashes.remove(atOffsets:$0); save() }
                                    .onMove { list.hashes.move(fromOffsets:$0,toOffset:$1); save() }
                            }
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
                    do { document = PlaylistDocument(data:try JSONEncoder().encode(PlaylistExchange(playlists:lists))); exporting = true }
                    catch { message = error.localizedDescription }
                }
                Button("Import playlists") { importing = true }
                Text("Soundly JSON exchange. Contains names and file hashes, not music or absolute paths. Matching imported music resolves by exact file content; unavailable tracks are retained. Different encodings/tags require adding tracks again.").font(.footnote)
                if let message { Text(message).font(.footnote) }
            }
        }.navigationTitle("Playlists").soundlySurface()
            .onAppear { if let value = try? PlaylistExchange.decode(stored) { lists = value.playlists } }
            .fileExporter(isPresented:$exporting,document:document,contentType:.json,defaultFilename:"Soundly-playlists") { result in if case .failure(let error) = result { message = error.localizedDescription } }
            .fileImporter(isPresented:$importing,allowedContentTypes:[.json]) { result in
                do {
                    let url = try result.get(); let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    let attributes = try url.resourceValues(forKeys:[.fileSizeKey]); guard (attributes.fileSize ?? Int.max) <= 2*1024*1024 else { throw CocoaError(.fileReadTooLarge) }
                    let exchange = try PlaylistExchange.decode(Data(contentsOf:url))
                    for var list in exchange.playlists { list.id = UUID(); lists.append(list) }; save()
                    message = "Imported \(exchange.playlists.count) playlists. Music files are not included."
                } catch { message = "Import failed: \(error.localizedDescription)" }
            }
    }
    private func resolved(_ list:LocalPlaylist)->[Song] { list.hashes.compactMap { hash in songs.first { $0.fileHash == hash } } }
    private func save() {
        do { let bytes = try JSONEncoder().encode(PlaylistExchange(playlists:lists)); _ = try PlaylistExchange.decode(bytes); stored = bytes }
        catch { message = "Playlists could not be saved." }
    }
}
