import XCTest
@testable import SoundlyCore

final class SignalPathTests: XCTestCase {
    private func pcm(_ rate: Double = 96_000, channels: Int = 2,
                     bits: Int? = 24, representation: PCMFormat.Representation = .signedInteger) throws -> PCMFormat {
        try PCMFormat(sampleRate: rate, channels: channels, bitDepth: bits, representation: representation)
    }

    private func native() throws -> SignalPathSnapshot {
        let format = try pcm()
        return SignalPathSnapshot(source: format, sourceIsLossless: true,
                                  decoderOutput: format, engineOutput: format,
                                  processing: .bypassed, engineGain: 1,
                                  sessionIsActive: true, sessionSampleRate: 96_000,
                                  sessionChannels: 2, route: .usbAudio)
    }

    func testMatchingRatesNeverGrantBitVerification() throws {
        let assessment = SignalPathEvaluator.assess(try native())
        XCTAssertEqual(assessment.status, .nativeRateUnverified)
        XCTAssertTrue(assessment.explanation.contains("External digital capture"))
    }

    func testMatchingSourceAndSessionWithMissingEngineRemainsUnknown() throws {
        var path = try native()
        path.engineOutput = nil
        XCTAssertEqual(SignalPathEvaluator.assess(path).status, .unknown)
    }

    func testRouteMatrixNeverGrantsBitVerification() throws {
        for route in OutputRoute.allCases {
            var path = try native()
            path.route = route
            XCTAssertNotEqual(SignalPathEvaluator.assess(path).status, .verifiedBitPerfect, route.rawValue)
        }
    }

    func testConventionalBluetoothIsLossyEvenAtMatchingRates() throws {
        for route in [OutputRoute.bluetoothA2DP, .bluetoothHFP] {
            var path = try native()
            path.route = route
            XCTAssertEqual(SignalPathEvaluator.assess(path).status, .lossyTransport)
        }
    }

    func testAirPlayAndUnspecifiedLETransportStayUnknown() throws {
        for route in [OutputRoute.airPlay, .bluetoothLE, .unknown] {
            var path = try native()
            path.route = route
            XCTAssertEqual(SignalPathEvaluator.assess(path).status, .unknown)
        }
    }

    func testEngineResamplingCannotHideBehindMatchingSessionRate() throws {
        var path = try native()
        path.engineOutput = try pcm(48_000)
        XCTAssertEqual(SignalPathEvaluator.assess(path).status, .converted)
    }

    func testSessionRateMismatchIsConversion() throws {
        var path = try native()
        path.sessionSampleRate = 48_000
        XCTAssertEqual(SignalPathEvaluator.assess(path).status, .converted)
    }

    func testKnownMismatchSurvivesMissingStage() throws {
        var path = try native()
        path.decoderOutput = nil
        path.sessionSampleRate = 48_000
        XCTAssertEqual(SignalPathEvaluator.assess(path).status, .converted)
    }

    func testChannelMappingIsReported() throws {
        var path = try native()
        path.sessionChannels = 1
        XCTAssertEqual(SignalPathEvaluator.assess(path).status, .converted)
    }

    func testFloatDecoderIsNotMistakenForOriginalIntegerPCM() throws {
        var path = try native()
        path.decoderOutput = try pcm(bits: 32, representation: .floatingPoint)
        path.engineOutput = path.decoderOutput
        XCTAssertEqual(SignalPathEvaluator.assess(path).status, .converted)
    }

    func testWidthChangeIsReportedWithoutAssumingLoss() throws {
        var path = try native()
        path.engineOutput = try pcm(bits: 32)
        XCTAssertEqual(SignalPathEvaluator.assess(path).status, .converted)
    }

    func testDSPAndGainInvalidateNativeStatus() throws {
        var path = try native()
        path.processing = .applied
        XCTAssertEqual(SignalPathEvaluator.assess(path).status, .converted)
        path.processing = .bypassed
        path.engineGain = 0.5
        XCTAssertEqual(SignalPathEvaluator.assess(path).status, .converted)
    }

    func testMissingAndInvalidMeasurementsStayUnknown() throws {
        var variants: [SignalPathSnapshot] = []
        var path = try native(); path.engineGain = nil; variants.append(path)
        path = try native(); path.engineGain = .nan; variants.append(path)
        path = try native(); path.sessionSampleRate = 0; variants.append(path)
        path = try native(); path.sessionSampleRate = .infinity; variants.append(path)
        path = try native(); path.sessionChannels = 0; variants.append(path)
        path = try native(); path.processing = .unknown; variants.append(path)
        path = try native(); path.sourceIsLossless = nil; variants.append(path)
        path = try native(); path.source = try pcm(bits: nil); variants.append(path)
        path = try native(); path.source = try pcm(representation: .unknown); variants.append(path)
        for variant in variants {
            XCTAssertEqual(SignalPathEvaluator.assess(variant).status, .unknown)
        }
    }

    func testInactiveSessionCannotReusePreviousMeasurements() throws {
        var path = try native()
        path.sessionIsActive = false
        XCTAssertEqual(SignalPathEvaluator.assess(path).status, .unknown)
    }

    func testLossySourceIsNotLosslessBecauseItsContainerIsM4A() throws {
        var path = try native()
        path.sourceIsLossless = false
        XCTAssertEqual(SignalPathEvaluator.assess(path).status, .converted)
    }
}
