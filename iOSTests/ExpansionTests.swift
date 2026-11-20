import XCTest
import AVFoundation
import UIKit
import MediaPlayer
@testable import Soundly

final class ExpansionTests:XCTestCase {
    @MainActor func testSystemArtworkCanBeRequestedOffMainActor() async throws {
        let image = try XCTUnwrap(UIImage(systemName:"play.fill"))
        let box = ArtworkTestBox(SystemArtwork.make(image))
        let present = await Task.detached { box.value.image(at:CGSize(width:64,height:64)) != nil }.value
        XCTAssertTrue(present)
    }
    @MainActor func testAlternateIconsArePackaged() throws {
        let icons = try XCTUnwrap(Bundle.main.infoDictionary?["CFBundleIcons"] as? [String:Any])
        let alternatives = try XCTUnwrap(icons["CFBundleAlternateIcons"] as? [String:Any])
        for name in ["Aurora","Pulse","Orbit","Signature","Glacier","NeonS","Circuit","Hologram","Midnight"] {
            XCTAssertNotNil(alternatives["AppIcon-"+name])
            let preview = try XCTUnwrap(UIImage(named:"IconPreview-"+name))
            let attachment = XCTAttachment(image:preview);attachment.name = "App icon — "+name;attachment.lifetime = .keepAlways;add(attachment)
        }
    }
    func testIntegrityOverridesEQAndMalformedGainsAreClamped() {
        var value = AudioSettings(); value.equalizer = true; value.gains = [6]
        XCTAssertFalse(value.processing)
        value.integrity = false; XCTAssertTrue(value.validated.processing)
        value.gains = [.nan,100,-100]; XCTAssertEqual(value.validated.gains,[0,6,-12,0,0])
    }
    func testUpgradePreservesAudioPreferencesAndGatesFixedUSBRate() throws {
        let legacy = Data(#"{"integrity":false,"equalizer":true,"gains":[0,0,3,0,0]}"#.utf8)
        var settings = try JSONDecoder().decode(AudioSettings.self, from: legacy)
        XCTAssertTrue(settings.processing)
        XCTAssertEqual(settings.usbRate, .source)
        XCTAssertEqual(settings.buffer, .automatic)
        XCTAssertTrue(settings.usesDirectPath)

        settings.usbRate = .standard
        settings.buffer = .stable
        XCTAssertEqual(settings.requestedRate(source: 96_000, usb: true), 48_000)
        XCTAssertEqual(settings.requestedRate(source: 96_000, usb: false), 96_000)
        settings.integrity = true
        settings.preferDirect = false
        XCTAssertEqual(settings.requestedRate(source: 96_000, usb: true), 96_000)
        XCTAssertTrue(settings.usesDirectPath)
        XCTAssertFalse(settings.processing)
        XCTAssertEqual(try JSONDecoder().decode(AudioSettings.self, from: JSONEncoder().encode(settings)), settings)
    }
    func testPlaylistRoundtripPreservesOrderAndRejectsInvalidExchange() throws {
        let first = LocalPlaylist(name:"Travel",hashes:["b","a"])
        let bytes = try JSONEncoder().encode(PlaylistExchange(playlists:[first,LocalPlaylist(name:"Home")]))
        XCTAssertEqual(try PlaylistExchange.decode(bytes).playlists,[first,LocalPlaylist(id:try PlaylistExchange.decode(bytes).playlists[1].id,name:"Home")])
        let invalid = try JSONEncoder().encode(PlaylistExchange(playlists:[LocalPlaylist(name:"",hashes:[])]))
        XCTAssertThrowsError(try PlaylistExchange.decode(invalid))
    }
    func testActualEQGraphAndIntegrityBypass() async throws {
        let name = UUID().uuidString+".wav"
        let url = try LibraryPaths.directory("Music").appendingPathComponent(name)
        defer { try? FileManager.default.removeItem(at:url) }
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate:48000,channels:2))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat:format,frameCapacity:48000)); buffer.frameLength = 48000
        for c in 0..<2 { for i in 0..<48000 { buffer.floatChannelData![c][i] = Float(sin(Double(i)*0.1))*0.01 } }
        do { let file = try AVAudioFile(forWriting:url,settings:format.settings); try file.write(from:buffer) }
        let track = PlaybackTrack(id:UUID(),filename:name,title:"EQ test",artist:"Reference",album:"Test",artwork:nil,sourceQuality:"PCM")
        let audio = AudioTransport(); var settings = AudioSettings()
        settings.integrity = false; settings.equalizer = true; settings.gains[2] = 3
        await audio.setSettings(settings)
        let processed = try await audio.load(track)
        XCTAssertEqual(processed.signalPath.graphPath,.equalizer)
        XCTAssertEqual(processed.signalPath.snapshot.processing,.applied)
        await audio.stop()
        settings.integrity = true; await audio.setSettings(settings)
        let bypassed = try await audio.load(track)
        XCTAssertNotEqual(bypassed.signalPath.graphPath,.equalizer)
        XCTAssertEqual(bypassed.signalPath.snapshot.processing,.bypassed)
        await audio.stop()
    }
    func testSourceEnvelopeUsesActualDecodedSamples() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".wav")
        defer { try? FileManager.default.removeItem(at:url) }
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate:44100,channels:1))
        let frames: AVAudioFrameCount = 44_100
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        let channel = try XCTUnwrap(buffer.floatChannelData)[0]
        for i in 0..<Int(frames) {
            let time = Double(i) / format.sampleRate
            channel[i] = (0.25..<0.42).contains(time) ? Float(0.6 * sin(2 * .pi * 90 * time)) : 0
        }
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
        }
        let waveform = try SourceEnvelope.analyze(url)
        XCTAssertEqual(waveform.levels.count, 100)
        XCTAssertEqual(waveform.levels.first, 0)
        XCTAssertEqual(waveform.levels.last, 0)
        XCTAssertEqual(waveform.pulse(at: 0.12), 0)
        XCTAssertGreaterThan(waveform.pulse(at: 0.26), 0.5)
        XCTAssertLessThan(waveform.pulse(at: 0.95), 0.03)
        let before = waveform.flow(at: 0.12)
        let hit = waveform.flow(at: 0.26)
        let trail = waveform.flow(at: 0.61)
        XCTAssertEqual(before.max(), 0)
        XCTAssertGreaterThan(hit.max() ?? 0, 0.75)
        XCTAssertGreaterThan(trail.max() ?? 0, 0.45)
        XCTAssertLessThan(trail.first ?? 1, trail.max() ?? 0)
        XCTAssertEqual(waveform.pulse(at: 0.12, rhythm: .bass), 0)
        XCTAssertEqual(waveform.pulse(at: 0.12, rhythm: .dynamics), 0)
        XCTAssertGreaterThan(waveform.pulse(at: 0.30, rhythm: .bass), 0.8)
        XCTAssertGreaterThan(waveform.pulse(at: 0.30, rhythm: .dynamics), 0.8)
    }
}

// Read-only test handle: MediaPlayer artwork request handlers can run on a worker.
private final class ArtworkTestBox:@unchecked Sendable {
    let value:MPMediaItemArtwork
    init(_ value:MPMediaItemArtwork) { self.value = value }
}
