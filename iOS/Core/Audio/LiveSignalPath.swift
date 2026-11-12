import Foundation
import AVFoundation

struct LiveSignalPath: Sendable {
    var snapshot = SignalPathSnapshot()
    var source = SourceAudioInfo()
    var systemVolume: Float?
    var bufferDuration: Double?
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
