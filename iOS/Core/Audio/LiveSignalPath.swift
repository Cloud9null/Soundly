import Foundation
import AVFoundation

struct LiveSignalPath: Sendable {
    var snapshot = SignalPathSnapshot()
    var source = SourceAudioInfo()
    var systemVolume: Float?
    var bufferDuration: Double?
    var requestedRate:Double?
    var graphPath = AudioGraphPath.unknown
    var rateSummary:String {
        guard snapshot.sessionIsActive,
              let source = snapshot.source, let decoder = snapshot.decoderOutput, let output = snapshot.engineOutput,
              let rate = snapshot.sessionSampleRate, rate > 0 else { return "Sample-rate path not yet observed" }
        return Set([source.sampleRate,decoder.sampleRate,output.sampleRate,rate]).count == 1
            ? "Native rate across observed stages — not bit-verified"
            : "Sample-rate conversion observed"
    }
    var assessment: SignalPathAssessment { SignalPathEvaluator.assess(snapshot) }
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
