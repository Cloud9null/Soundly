import XCTest
@testable import Soundly

final class PlaylistM3UTests:XCTestCase {
    func testExistingJSONAndPendingReferencePersistence() throws {
        let old = Data("{\"soundlyVersion\":1,\"playlists\":[{\"id\":\"00000000-0000-0000-0000-000000000001\",\"name\":\"Old\",\"hashes\":[\"a\"]}]}".utf8)
        XCTAssertNil(try PlaylistExchange.decode(old).playlists[0].unresolved)
        let pending = M3UEntry(reference:"missing.flac",title:"Pending song")
        let list = LocalPlaylist(name:"Portable",hashes:["a"],unresolved:[pending])
        let data = try JSONEncoder().encode(PlaylistExchange(playlists:[list]))
        XCTAssertEqual(try PlaylistExchange.decode(data).playlists,[list])
        let invalid = LocalPlaylist(name:"Unsafe",unresolved:[M3UEntry(reference:"../escape.flac")])
        XCTAssertThrowsError(try PlaylistExchange.decode(JSONEncoder().encode(PlaylistExchange(playlists:[invalid]))))
    }
    @MainActor func testActualSongCatalogResolvesExportWithoutMusicAccess() throws {
        let hash = String(repeating:"a",count:64)
        let song = Song(ImportedSong(hash:hash,filename:hash+".flac",metadata:MusicMetadata(title:"Song",artist:"Artist",album:"Album"),size:100,artwork:nil,folder:"Test"))
        let bytes = try M3U.encode([M3UEntry(reference:song.filename,title:song.artist+" - "+song.title,sha256:song.fileHash)])
        let parsed = try M3U.parse(bytes)
        let result = M3U.resolve(parsed.entries,catalog:[M3UCatalogItem(hash:song.fileHash,filename:song.filename,title:song.title,artist:song.artist)])
        XCTAssertEqual(result.hashes,[hash]);XCTAssertTrue(result.unresolved.isEmpty)
    }
}
