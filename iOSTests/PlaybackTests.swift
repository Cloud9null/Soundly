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
    private func render(codec:AudioFormatID,extension suffix:String) throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(suffix)
        defer { try? FileManager.default.removeItem(at:url) }
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate:44100,channels:2))
        let count:AVAudioFrameCount = 2048
        let input = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat:format,frameCapacity:count)); input.frameLength = count
        let values = try XCTUnwrap(input.floatChannelData)
        for i in 0..<Int(count) { values[0][i] = i%2 == 0 ? 0.25 : -0.125; values[1][i] = i%2 == 0 ? -0.375 : 0.0625 }
        var settings:[String:Any] = [AVFormatIDKey:codec,AVSampleRateKey:44100,AVNumberOfChannelsKey:2]
        if codec == kAudioFormatLinearPCM { settings[AVLinearPCMBitDepthKey] = 16; settings[AVLinearPCMIsFloatKey] = false }
        else { settings[AVEncoderBitDepthHintKey] = 16 }
        do { let writer = try AVAudioFile(forWriting:url,settings:settings,commonFormat:.pcmFormatFloat32,interleaved:false); try writer.write(from:input) }
        let source = try AVAudioFile(forReading:url)
        XCTAssertEqual(source.processingFormat.sampleRate,44100)
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
