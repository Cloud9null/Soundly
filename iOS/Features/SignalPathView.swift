import SwiftUI

struct SignalPathView: View {
    @Environment(PlaybackController.self) private var playback
    private var report: LiveSignalPath { playback.audio.signalPath }
    private var snapshot: SignalPathSnapshot { report.snapshot }
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:16) {
                Label(report.assessment.status.rawValue,systemImage:statusSymbol).font(.title2.bold())
                    .accessibilityIdentifier("signalPathStatus")
                Text(report.assessment.explanation).foregroundStyle(.secondary)
                if !playback.audio.playing { Label("Playback is paused or stopped. Values describe observed configuration, not verified output samples.",systemImage:"pause.circle").font(.footnote) }
                stage("1",title:"Source",evidence:"FILE METADATA",icon:"doc.waveform") {
                    Text(report.source.codec).font(.headline)
                    Text(Self.format(snapshot.source))
                    Text(report.source.note).font(.footnote).foregroundStyle(.secondary)
                }
                stage("2",title:"Decoder",evidence:"API REPORTED",icon:"waveform") {
                    Text("\(report.source.codec) → PCM").font(.headline)
                    Text(Self.format(snapshot.decoderOutput))
                    Text("AVAudioFile processing format. Decoder sample width is separate from original file depth.").font(.footnote).foregroundStyle(.secondary)
                }
                stage("3",title:"Audio engine",evidence:"API REPORTED",icon:"slider.horizontal.3") {
                    Text(Self.format(snapshot.engineOutput))
                    Text("AVAudioPlayerNode → Apple main mixer → output")
                    LabeledContent("Application gain",value:snapshot.engineGain.map { String(format:"%.3f",$0) } ?? "Unknown")
                    Text(snapshot.processing == .bypassed ? "No optional DSP, EQ, normalization or crossfade. Apple's mixer is present." : "Engine processing has not been observed.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                stage("4",title:"iOS audio session",evidence:"API REPORTED",icon:"iphone") {
                    LabeledContent("Session active",value:snapshot.sessionIsActive ? "Activation observed" : "Not active / not observed")
                    LabeledContent("Effective session rate",value:Self.rate(snapshot.sessionSampleRate))
                    LabeledContent("Output channels",value:snapshot.sessionChannels.map(String.init) ?? "Unknown")
                    LabeledContent("I/O buffer",value:report.bufferDuration.map { String(format:"%.2f ms",$0*1000) } ?? "Unknown")
                    LabeledContent("System volume",value:report.systemVolume.map { String(format:"%.0f%%",$0*100) } ?? "Unknown")
                    Text("System volume alone does not identify downstream digital gain or physical DAC processing.").font(.footnote).foregroundStyle(.secondary)
                    if let note = playback.audio.rateRequestNote { Text(note).font(.footnote) }
                }
                stage("5",title:"Output route",evidence:"API REPORTED + UNAVAILABLE",icon:"hifispeaker") {
                    Text(playback.audio.route).font(.headline)
                    Text(playback.audio.routeTypes.isEmpty ? "Port type not observed" : playback.audio.routeTypes.joined(separator:", ")).font(.caption.monospaced())
                    LabeledContent("DAC effective bit depth",value:"Unknown")
                    LabeledContent("USB chip / capability table",value:"Not exposed here")
                    Text("Only iOS-exposed port names/types and session channels are shown. AirPlay and unspecified Bluetooth transports remain unverified.").font(.footnote).foregroundStyle(.secondary)
                }
                stage("6",title:"Assessment",evidence:"INFERRED — NOT BIT VERIFIED",icon:"checkmark.shield") {
                    Text(report.assessment.status.rawValue).font(.headline)
                    Text(report.assessment.explanation)
                    Text("Integer/float or sample-width conversion is reported conservatively; it does not necessarily imply lost information. Rate equality does not prove sample identity. External digital capture is required for a specifically tested route.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Text("Evidence labels distinguish parsed source metadata, iOS/API observations, inferred conversion and unavailable physical measurements. No value is a fabricated DAC capability.")
                    .font(.footnote).foregroundStyle(.secondary)
            }.padding()
        }.soundlySurface().navigationTitle("Signal Path").navigationBarTitleDisplayMode(.inline)
    }
    private var statusSymbol:String {
        switch report.assessment.status {
        case .lossyTransport: "antenna.radiowaves.left.and.right"
        case .converted: "arrow.triangle.2.circlepath"
        case .nativeRateUnverified: "waveform.path"
        case .verifiedBitPerfect: "checkmark.seal"
        case .unknown: "questionmark.circle"
        }
    }
    private func stage<Content:View>(_ number:String,title:String,evidence:String,icon:String,@ViewBuilder content:()->Content)->some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {
                Image(systemName:icon).foregroundStyle(.tint)
                Text(title).font(.headline)
                Spacer()
                Text(number).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Text(evidence).font(.caption2.weight(.semibold)).tracking(0.8).foregroundStyle(.secondary)
            content()
        }.frame(maxWidth:.infinity,alignment:.leading).padding(18)
            .background(.tint.opacity(0.06),in:RoundedRectangle(cornerRadius:22))
    }
    static func rate(_ value:Double?)->String { value.map { String(format:"%.1f kHz",$0/1000) } ?? "Unknown" }
    static func format(_ format:PCMFormat?)->String {
        guard let format else { return "Not observed / unknown" }
        let representation:String
        switch format.representation { case .signedInteger: representation = "Integer"; case .floatingPoint: representation = "Float"; case .unknown: representation = "Representation unknown" }
        return "\(representation) · \(format.bitDepth.map { "\($0)-bit" } ?? "Depth unknown") · \(rate(format.sampleRate)) · \(format.channels) ch"
    }
}
