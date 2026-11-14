import SwiftUI

struct AudioSettings:Codable,Equatable,Sendable {
    var integrity = true
    var equalizer = false
    var gains:[Float] = Array(repeating:0,count:5)
    static let frequencies:[Float] = [60,250,1000,4000,12000]
    var processing:Bool { !integrity && equalizer && gains.contains { $0 != 0 } }
    var validated:Self {
        var copy = self
        copy.gains = (0..<5).map { i in i < gains.count && gains[i].isFinite ? min(6,max(-12,gains[i])) : 0 }
        return copy
    }
}
struct AudioSettingsView:View {
    @Environment(PlaybackController.self) private var playback
    @State private var settings = AudioSettings()
    var body:some View {
        Form {
            Section("Signal integrity") {
                Toggle("Bit-perfect-oriented mode",isOn:$settings.integrity)
                Text("Default on. Bypasses optional DSP and requests the original rate. This cannot grant exclusive iOS/USB access or verify physical output bits.").font(.footnote)
            }
            Section("Equalizer / DSP") {
                Toggle("Equalizer",isOn:$settings.equalizer).disabled(settings.integrity)
                ForEach(0..<5,id:\.self) { i in
                    VStack(alignment:.leading) {
                        Text("\(Int(AudioSettings.frequencies[i])) Hz · \(settings.gains[i],specifier:"%.1f") dB").font(.caption.monospaced())
                        Slider(value:$settings.gains[i],in:-12...6,step:1).accessibilityLabel("EQ band \(i+1)")
                    }.disabled(settings.integrity || !settings.equalizer)
                }
                Text("EQ uses Apple's AVAudioUnitEQ. When active, output is modified and a −6 dB preamp provides headroom; this is not a clipping guarantee. No normalization or crossfade is added.").font(.footnote)
            }
            Button("Apply audio settings") { playback.applyAudioSettings(settings) }
                .disabled(playback.busy).accessibilityIdentifier("applyAudioSettings")
            NavigationLink("Signal Path",destination:SignalPathView())
        }.navigationTitle("Audio & Playback").soundlySurface()
            .onAppear { settings = playback.settings }
    }
}
