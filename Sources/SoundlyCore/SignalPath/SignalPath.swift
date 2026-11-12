import Foundation

public enum OutputRoute: String, CaseIterable, Sendable {
    case builtInSpeaker, builtInReceiver, wiredHeadphones, usbAudio
    case bluetoothA2DP, bluetoothHFP, bluetoothLE, airPlay, unknown
}

public enum ProcessingState: Equatable, Sendable {
    case bypassed, applied, unknown
}

/// Capture a fresh snapshot after activation, route/configuration changes and gain changes.
/// Do not reuse a snapshot across routes, files, or sessions.
public struct SignalPathSnapshot: Sendable {
    public var source: PCMFormat?
    public var sourceIsLossless: Bool?
    public var decoderOutput: PCMFormat?
    public var engineOutput: PCMFormat?
    public var processing: ProcessingState
    public var engineGain: Double?
    public var sessionIsActive: Bool
    /// API-reported client-facing rate; it does not expose every physical DAC stage.
    public var sessionSampleRate: Double?
    public var sessionChannels: Int?
    public var route: OutputRoute

    public init(source: PCMFormat? = nil, sourceIsLossless: Bool? = nil,
                decoderOutput: PCMFormat? = nil, engineOutput: PCMFormat? = nil,
                processing: ProcessingState = .unknown, engineGain: Double? = nil,
                sessionIsActive: Bool = false, sessionSampleRate: Double? = nil,
                sessionChannels: Int? = nil, route: OutputRoute = .unknown) {
        self.source = source
        self.sourceIsLossless = sourceIsLossless
        self.decoderOutput = decoderOutput
        self.engineOutput = engineOutput
        self.processing = processing
        self.engineGain = engineGain
        self.sessionIsActive = sessionIsActive
        self.sessionSampleRate = sessionSampleRate
        self.sessionChannels = sessionChannels
        self.route = route
    }
}

public struct SignalPathAssessment: Equatable, Sendable {
    public enum Status: String, Sendable {
        // Reserved. Runtime metadata cannot produce this status.
        case verifiedBitPerfect = "Verified Bit-Perfect"
        case nativeRateUnverified = "Native Sample Rate — Not Bit-Verified"
        case converted = "Converted / Resampled"
        case lossyTransport = "Lossy Transport"
        case unknown = "Unknown / Not Verified"
    }
    public let status: Status
    public let explanation: String
}

/// Pure policy, deliberately incapable of granting external bit verification.
/// An integer/float representation change is reported conservatively as conversion;
/// it is not a claim that the conversion necessarily lost information.
public enum SignalPathEvaluator {
    public static func assess(_ path: SignalPathSnapshot) -> SignalPathAssessment {
        guard path.sessionIsActive else {
            return result(.unknown, "No active audio session has been observed.")
        }
        if path.route == .bluetoothA2DP || path.route == .bluetoothHFP {
            return result(.lossyTransport,
                          "Conventional Bluetooth audio uses a lossy transport. The negotiated codec is not exposed here.")
        }
        if path.processing == .applied {
            return result(.converted, "DSP or mixing has modified the signal.")
        }
        if let gain = path.engineGain, gain.isFinite, gain != 1 {
            return result(.converted, "Application digital gain is not unity.")
        }
        let formats = [path.source, path.decoderOutput, path.engineOutput].compactMap { $0 }
        // A known mismatch is useful even when another stage is unavailable.
        var rates = formats.map(\.sampleRate)
        if let rate = path.sessionSampleRate, rate.isFinite, rate > 0 { rates.append(rate) }
        if Set(rates).count > 1 {
            return result(.converted, "Observed sample rates differ between stages; rate conversion is indicated.")
        }
        var channels = formats.map(\.channels)
        if let count = path.sessionChannels, count > 0 { channels.append(count) }
        if Set(channels).count > 1 {
            return result(.converted, "Observed channel counts differ; channel mapping or mixing is indicated.")
        }
        for (first, second) in [(path.source, path.decoderOutput), (path.decoderOutput, path.engineOutput)] {
            if let first, let second {
                if first.representation != .unknown, second.representation != .unknown,
                   first.representation != second.representation {
                    return result(.converted, "PCM representation changes between integer and floating point. Bit identity is not established.")
                }
                if let a = first.bitDepth, let b = second.bitDepth, a != b {
                    return result(.converted, "PCM sample width changes between stages. Bit identity is not established.")
                }
            }
        }
        if path.sourceIsLossless == false {
            return result(.converted, "The source codec is lossy; decoding cannot restore its original PCM.")
        }
        guard formats.count == 3, path.sourceIsLossless == true,
              path.processing == .bypassed, path.engineGain == 1,
              let rate = path.sessionSampleRate, rate.isFinite, rate > 0,
              let count = path.sessionChannels, count > 0,
              formats.allSatisfy({ $0.bitDepth != nil && $0.representation != .unknown }),
              [.builtInSpeaker, .builtInReceiver, .wiredHeadphones, .usbAudio].contains(path.route) else {
            return result(.unknown, "One or more stages or the transport are unverified. No end-to-end digital capture is available.")
        }
        return result(.nativeRateUnverified,
                      "All observed rates match. iOS does not expose every downstream processing stage, effective DAC bit depth, or sample identity. External digital capture is required; system volume alone is not proof of unity digital gain.")
    }

    private static func result(_ status: SignalPathAssessment.Status, _ explanation: String) -> SignalPathAssessment {
        SignalPathAssessment(status: status, explanation: explanation)
    }
}
