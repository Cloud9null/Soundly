import XCTest
import AVFoundation
@testable import Soundly

final class PlaybackQueueTests: XCTestCase {
    private func tracks()->[PlaybackTrack] {
        (0..<3).map { PlaybackTrack(id:UUID(),filename:"\($0).wav",title:"\($0)",artist:"Test",album:"Test",artwork:nil,sourceQuality:"PCM") }
    }
    func testRepeatOneOnlyRepeatsOnAutomaticCompletion() {
        let songs = tracks(); var queue = PlaybackQueue(); queue.replace(songs,starting:songs[0].id)
        queue.repeatMode = .one
        XCTAssertTrue(queue.advance(automatic:true)); XCTAssertEqual(queue.current?.id,songs[0].id)
        XCTAssertTrue(queue.advance(automatic:false)); XCTAssertEqual(queue.current?.id,songs[1].id)
    }
    func testEndOfQueueAndRepeatAllWraparound() {
        let songs = tracks(); var queue = PlaybackQueue(); queue.replace(songs,starting:songs[2].id)
        XCTAssertFalse(queue.advance(automatic:true))
        queue.repeatMode = .all
        XCTAssertTrue(queue.advance(automatic:true)); XCTAssertEqual(queue.current?.id,songs[0].id)
        queue.previous(); XCTAssertEqual(queue.current?.id,songs[2].id)
    }
    func testShuffleNeverPicksSameTrackWhenAlternativesExist() {
        let songs = tracks(); var queue = PlaybackQueue(); queue.replace(songs,starting:songs[0].id); queue.shuffle = true
        for _ in 0..<20 { let previous = queue.current?.id; XCTAssertTrue(queue.advance(automatic:true)); XCTAssertNotEqual(queue.current?.id,previous) }
    }
    func testEmptyQueueAndPersistence() throws {
        var queue = PlaybackQueue(); XCTAssertFalse(queue.advance(automatic:true)); queue.previous(); XCTAssertNil(queue.current)
        let songs = tracks(); queue.replace(songs,starting:songs[1].id); queue.repeatMode = .all; queue.shuffle = true
        XCTAssertEqual(try JSONDecoder().decode(PlaybackQueue.self,from:JSONEncoder().encode(queue)),queue)
    }
    func testSeekBoundsRejectInvalidTimes() {
        XCTAssertEqual(AudioTransport.frame(.nan,rate:44100,length:100),0)
        XCTAssertEqual(AudioTransport.frame(-4,rate:44100,length:100),0)
        XCTAssertEqual(AudioTransport.frame(100,rate:44100,length:100),99)
        XCTAssertEqual(AudioTransport.frame(0.5,rate:44100,length:44100),22050)
    }
}

/// Verifies decoded PCM through the actual production graph in offline mode.
/// These tests never exercise AVAudioSession, USB, Bluetooth or physical output.
final class PCMRenderingTests: XCTestCase {
    func testWAVIntegerDecodeAndOfflineChannelMapping() throws { try render(codec:kAudioFormatLinearPCM,extension:"wav") }
    func testALACDecodeAndOfflineChannelMapping() throws { try render(codec:kAudioFormatAppleLossless,extension:"m4a") }
    func testFLAC16Bit44100DecodedThroughProductionGraph() throws { try render(codec:kAudioFormatFLAC,extension:"flac",fixture:FLACFixtures.pcm16) }
    func testFLAC24Bit96000DecodedThroughProductionGraph() throws { try render(codec:kAudioFormatFLAC,extension:"flac",rate:96000,fixture:FLACFixtures.pcm24) }
    private func render(codec:AudioFormatID,extension suffix:String,rate:Double = 44100,fixture:String? = nil) throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(suffix)
        defer { try? FileManager.default.removeItem(at:url) }
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate:rate,channels:2))
        let count:AVAudioFrameCount = 2048
        let input = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat:format,frameCapacity:count)); input.frameLength = count
        let values = try XCTUnwrap(input.floatChannelData)
        for i in 0..<Int(count) { values[0][i] = i%2 == 0 ? 0.25 : -0.125; values[1][i] = i%2 == 0 ? -0.375 : 0.0625 }
        var settings:[String:Any] = [AVFormatIDKey:codec,AVSampleRateKey:rate,AVNumberOfChannelsKey:2]
        if codec == kAudioFormatLinearPCM { settings[AVLinearPCMBitDepthKey] = 16; settings[AVLinearPCMIsFloatKey] = false }
        else { settings[AVEncoderBitDepthHintKey] = 16 }
        if let fixture { try XCTUnwrap(Data(base64Encoded:fixture)).write(to:url) }
        else { let writer = try AVAudioFile(forWriting:url,settings:settings,commonFormat:.pcmFormatFloat32,interleaved:false); try writer.write(from:input) }
        let source = try AVAudioFile(forReading:url)
        XCTAssertEqual(source.processingFormat.sampleRate,rate)
        XCTAssertEqual(source.length,Int64(count))
        let engine = AVAudioEngine(); let player = AVAudioPlayerNode(); engine.attach(player)
        PCMGraph.connect(engine:engine,player:player,format:source.processingFormat)
        try engine.enableManualRenderingMode(.offline,format:format,maximumFrameCount:count)
        defer { player.stop(); engine.stop() }
        player.scheduleFile(source,at:nil)
        try engine.start(); player.play()
        let output = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat:format,frameCapacity:count))
        var rendered = false
        for _ in 0..<20 {
            if try engine.renderOffline(count,to:output) == .success { rendered = true; break }
        }
        XCTAssertTrue(rendered); XCTAssertEqual(output.frameLength,count)
        let result = try XCTUnwrap(output.floatChannelData)
        for channel in 0..<2 {
            for i in 0..<Int(count) { XCTAssertEqual(result[channel][i],values[channel][i],accuracy:1.0/32768,"Channel \(channel), frame \(i)") }
        }
    }
}

/// Exercises the actual AVAudioSession/output timeline in the iOS simulator.
/// Clock advancement is not an audible or physical bit-identity test.
final class RealtimeTransportTests: XCTestCase {
    func testPlayPauseSeekResumeAndStopOnSimulatorRoute() async throws {
        let name = UUID().uuidString+".wav"
        let url = try LibraryPaths.directory("Music").appendingPathComponent(name)
        defer { try? FileManager.default.removeItem(at:url) }
        do {
            let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate:44100,channels:2))
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat:format,frameCapacity:88200)); buffer.frameLength = 88200
            let data = try XCTUnwrap(buffer.floatChannelData)
            for c in 0..<2 { for i in 0..<88200 { data[c][i] = i%2 == 0 ? 0.005 : -0.005 } }
            let writer = try AVAudioFile(forWriting:url,settings:[AVFormatIDKey:kAudioFormatLinearPCM,AVSampleRateKey:44100,AVNumberOfChannelsKey:2,AVLinearPCMBitDepthKey:16],commonFormat:.pcmFormatFloat32,interleaved:false)
            try writer.write(from:buffer)
        }
        let track = PlaybackTrack(id:UUID(),filename:name,title:"Synthetic route test",artist:"Soundly",album:"Tests",artwork:nil,sourceQuality:"PCM 16-bit / 44.1 kHz")
        let transport = AudioTransport()
        do {
            let loaded = try await transport.load(track)
            XCTAssertTrue(loaded.playing); XCTAssertEqual(loaded.duration,2,accuracy:0.001)
            var running = await transport.observation()
            for _ in 0..<10 where running.elapsed <= 0 {
                try await Task.sleep(for:.milliseconds(100))
                running = await transport.observation()
            }
            XCTAssertGreaterThan(running.elapsed,0,"Output timeline did not advance")
            await transport.pause()
            let paused = await transport.observation(); XCTAssertFalse(paused.playing)
            try await Task.sleep(for:.milliseconds(50))
            let still = await transport.observation(); XCTAssertEqual(paused.elapsed,still.elapsed,accuracy:0.001)
            try await transport.seek(0.7)
            let sought = await transport.observation(); XCTAssertEqual(sought.elapsed,0.7,accuracy:0.001)
            try await transport.resume()
            let resumed = await transport.observation(); XCTAssertTrue(resumed.playing)
            await transport.stop()
            let stopped = await transport.observation(); XCTAssertFalse(stopped.playing); XCTAssertEqual(stopped.elapsed,0)
        } catch { await transport.stop(); throw error }
    }
}
