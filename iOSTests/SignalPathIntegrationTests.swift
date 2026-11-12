import XCTest
import AVFoundation
@testable import Soundly

final class SignalPathIntegrationTests: XCTestCase {
    func testActualFLACSourceDepthDoesNotBecomeDecoderFloatWidth() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".flac")
        defer { try? FileManager.default.removeItem(at:url) }
        try XCTUnwrap(Data(base64Encoded:FLACFixtures.pcm24)).write(to:url)
        let file = try AVAudioFile(forReading:url)
        let info = try SourceFormatInspector.inspect(file,url:url)
        XCTAssertEqual(info.codec,"FLAC"); XCTAssertEqual(info.pcm?.bitDepth,24)
        XCTAssertEqual(info.pcm?.sampleRate,96000); XCTAssertEqual(info.pcm?.representation,.signedInteger)
        let decoded = try XCTUnwrap(SourceFormatInspector.pcm(file.processingFormat))
        XCTAssertEqual(decoded.representation,.floatingPoint); XCTAssertEqual(decoded.bitDepth,32)
        let snapshot = SignalPathSnapshot(source:info.pcm,sourceIsLossless:info.lossless,decoderOutput:decoded,engineOutput:decoded,processing:.bypassed,engineGain:1,sessionIsActive:true,sessionSampleRate:96000,sessionChannels:2,route:.usbAudio)
        XCTAssertEqual(SignalPathEvaluator.assess(snapshot).status,.converted)
    }
    func testAllExposedPortsAndMultipleOutputFallback() {
        XCTAssertEqual(LiveSignalPath.route([AVAudioSession.Port.usbAudio.rawValue]),.usbAudio)
        XCTAssertEqual(LiveSignalPath.route([AVAudioSession.Port.bluetoothA2DP.rawValue]),.bluetoothA2DP)
        XCTAssertEqual(LiveSignalPath.route([AVAudioSession.Port.bluetoothHFP.rawValue]),.bluetoothHFP)
        XCTAssertEqual(LiveSignalPath.route([AVAudioSession.Port.bluetoothLE.rawValue]),.bluetoothLE)
        XCTAssertEqual(LiveSignalPath.route([AVAudioSession.Port.airPlay.rawValue]),.airPlay)
        XCTAssertEqual(LiveSignalPath.route([AVAudioSession.Port.headphones.rawValue]),.wiredHeadphones)
        XCTAssertEqual(LiveSignalPath.route([]),.unknown)
        XCTAssertEqual(LiveSignalPath.route(["undocumented"]),.unknown)
        XCTAssertEqual(LiveSignalPath.route([AVAudioSession.Port.usbAudio.rawValue,AVAudioSession.Port.builtInSpeaker.rawValue]),.unknown)
    }
    func testNoObservationsCannotProduceNativeOrVerifiedStatus() {
        let report = LiveSignalPath()
        XCTAssertNil(report.snapshot.source); XCTAssertNil(report.systemVolume)
        XCTAssertEqual(report.assessment.status,.unknown)
    }
}
