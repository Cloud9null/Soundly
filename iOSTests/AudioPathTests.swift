import XCTest
import AVFoundation
@testable import Soundly

final class AudioPathTests:XCTestCase {
    func testDirectPathRequiresMatchingRateChannelsAndRepresentation() throws {
        let source = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate:44100,channels:2))
        XCTAssertEqual(PCMGraph.path(source:source,output:source),.direct)
        XCTAssertEqual(PCMGraph.path(source:source,output:nil),.systemMixer)
        XCTAssertEqual(PCMGraph.path(source:source,output:AVAudioFormat(standardFormatWithSampleRate:48000,channels:2)),.systemMixer)
        XCTAssertEqual(PCMGraph.path(source:source,output:AVAudioFormat(standardFormatWithSampleRate:44100,channels:1)),.systemMixer)
        XCTAssertEqual(PCMGraph.path(source:source,output:AVAudioFormat(commonFormat:.pcmFormatInt16,sampleRate:44100,channels:2,interleaved:true)),.systemMixer)
    }
    func testRateEqualityDoesNotHideIntegerFloatConversion() throws {
        var report = LiveSignalPath()
        report.snapshot.source = try PCMFormat(sampleRate:44100,channels:2,bitDepth:24,representation:.signedInteger)
        report.snapshot.sourceIsLossless = true
        report.snapshot.decoderOutput = try PCMFormat(sampleRate:44100,channels:2,bitDepth:32,representation:.floatingPoint)
        report.snapshot.engineOutput = report.snapshot.decoderOutput
        report.snapshot.sessionIsActive = true; report.snapshot.sessionSampleRate = 44100; report.snapshot.sessionChannels = 2
        report.snapshot.engineGain = 1; report.snapshot.processing = .bypassed; report.snapshot.route = .usbAudio
        report.graphPath = .direct
        XCTAssertTrue(report.rateSummary.hasPrefix("Native rate")); XCTAssertEqual(report.assessment.status,.converted)
        report.snapshot.sessionSampleRate = 48000
        XCTAssertEqual(report.rateSummary,"Sample-rate conversion observed")
        report.snapshot.sessionIsActive = false
        XCTAssertEqual(report.rateSummary,"Sample-rate path not yet observed")
    }
    func testQueuePruningPreservesCurrentTrackAndPosition() {
        let tracks = (0..<3).map { PlaybackTrack(id:UUID(),filename:"\($0).wav",title:"Reference",artist:"Test",album:"Test",artwork:nil,sourceQuality:"PCM") }
        var queue = PlaybackQueue(); queue.replace(tracks,starting:tracks[1].id)
        queue.remove([tracks[0].id]); XCTAssertEqual(queue.current?.id,tracks[1].id); XCTAssertEqual(queue.positionLabel,"Track 1 of 2")
        queue.remove(Set(tracks.map(\.id))); XCTAssertNil(queue.current); XCTAssertEqual(queue.positionLabel,"No track selected")
    }
}
