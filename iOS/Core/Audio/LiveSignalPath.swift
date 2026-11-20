import Foundation
import AVFoundation

struct LiveSignalPath: Sendable {
    var snapshot = SignalPathSnapshot()
    var source = SourceAudioInfo()
    var systemVolume: Float?
    var requestedBuffer: TimeInterval?
    var bufferRequestNote: String?
    var outputLatency: TimeInterval?
    var bufferDuration: Double?
    var requestedRate:Double?
    var graphPath = AudioGraphPath.unknown
    var outputNodeInput:PCMFormat?
    var rateSummary:String {
        guard snapshot.sessionIsActive,
              let source = snapshot.source, let decoder = snapshot.decoderOutput, let output = snapshot.engineOutput,
              let rate = snapshot.sessionSampleRate, rate > 0 else { return "Sample-rate path not yet observed" }
        let rates = [source.sampleRate,decoder.sampleRate,output.sampleRate,rate] + [snapshot.deviceOutput?.sampleRate].compactMap { $0 }
        return Set(rates).count == 1
            ? "Native rate across observed stages — not bit-verified"
            : "Sample-rate conversion observed"
    }
    var assessment: SignalPathAssessment { SignalPathEvaluator.assess(snapshot) }
    var outputRate: Double? {
        guard snapshot.sessionIsActive else { return nil }
        return snapshot.deviceOutput?.sampleRate ?? snapshot.sessionSampleRate.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
    }

    var outputBitrate: Double? {
        guard snapshot.sessionIsActive else { return nil }
        return snapshot.deviceOutput?.payloadKilobitsPerSecond
    }

    var rateComparison:String {
        guard snapshot.sessionIsActive,let source = snapshot.source?.sampleRate,
              let rate = outputRate,source > 0 else { return "Source → iOS output: not observed" }
        let from = String(format:"%.1f kHz",source/1000)
        let to = String(format:"%.1f kHz",rate/1000)
        return from+" → "+to+(source == rate ? " · Same endpoint rate" : " · Resampled")
    }
    var transportLabel:String {
        switch snapshot.route {
        case .bluetoothA2DP: "Bluetooth A2DP · lossy transport"
        case .bluetoothHFP: "Bluetooth hands-free · voice transport"
        case .bluetoothLE: "Bluetooth LE · codec unreported"
        case .usbAudio: "USB audio · PCM interface"
        case .wiredHeadphones: "Wired headphones · analog output"
        case .builtInSpeaker,.builtInReceiver: "Built-in · analog output"
        case .airPlay: "AirPlay · transport unreported"
        case .unknown: "Transport not observed"
        }
    }
    static func route(_ portTypes:[String])->OutputRoute {
        guard portTypes.count == 1, let type = portTypes.first else { return .unknown }
        switch type {
        case AVAudioSession.Port.builtInSpeaker.rawValue: return .builtInSpeaker
        case AVAudioSession.Port.builtInReceiver.rawValue: return .builtInReceiver
        case AVAudioSession.Port.headphones.rawValue: return .wiredHeadphones
        case AVAudioSession.Port.usbAudio.rawValue: return .usbAudio
        case AVAudioSession.Port.bluetoothA2DP.rawValue: return .bluetoothA2DP
        case AVAudioSession.Port.bluetoothHFP.rawValue: return .bluetoothHFP
        case AVAudioSession.Port.bluetoothLE.rawValue: return .bluetoothLE
        case AVAudioSession.Port.airPlay.rawValue: return .airPlay
        default: return .unknown
        }
    }
}
