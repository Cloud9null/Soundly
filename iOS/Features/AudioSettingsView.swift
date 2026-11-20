import SwiftUI

struct AudioSettings: Codable, Equatable, Sendable {
    enum USBRate: Int, Codable, CaseIterable, Sendable {
        case source = 0
        case cd = 44100, standard = 48000, doubleCD = 88200, double = 96000
        case quadCD = 176400, quad = 192000

        var label: String {
            self == .source ? "Match source" : String(format: "%.1f kHz", Double(rawValue) / 1_000)
        }
    }

    enum Buffer: Int, Codable, CaseIterable, Sendable {
        case automatic = 0, responsive = 10, balanced = 23, stable = 46

        var duration: TimeInterval? {
            self == .automatic ? nil : Double(rawValue) / 1000
        }

        var label: String {
            switch self {
            case .automatic: "Automatic"
            case .responsive: "Responsive · 10 ms"
            case .balanced: "Balanced · 23 ms"
            case .stable: "Stable · 46 ms"
            }
        }
    }

    var integrity = true
    var equalizer = false
    var gains: [Float] = Array(repeating: 0, count: 5)
    var usbRate: USBRate = .source
    var buffer: Buffer = .automatic
    var preferDirect = true
    static let frequencies: [Float] = [60, 250, 1000, 4000, 12000]

    private enum CodingKeys: String, CodingKey {
        case integrity, equalizer, gains, usbRate, buffer, preferDirect
    }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        integrity = try values.decodeIfPresent(Bool.self, forKey: .integrity) ?? integrity
        equalizer = try values.decodeIfPresent(Bool.self, forKey: .equalizer) ?? equalizer
        gains = try values.decodeIfPresent([Float].self, forKey: .gains) ?? gains
        usbRate = try values.decodeIfPresent(USBRate.self, forKey: .usbRate) ?? usbRate
        buffer = try values.decodeIfPresent(Buffer.self, forKey: .buffer) ?? buffer
        preferDirect = try values.decodeIfPresent(Bool.self, forKey: .preferDirect) ?? preferDirect
    }

    var processing: Bool { !integrity && equalizer && gains.contains { $0 != 0 } }

    var usesDirectPath: Bool { integrity || preferDirect }

    func requestedRate(source: Double, usb: Bool) -> Double {
        guard !integrity, usb, usbRate != .source else { return source }
        return Double(usbRate.rawValue)
    }

    var validated: Self {
        var copy = self
        copy.gains = Self.frequencies.indices.map { i in
            i < gains.count && gains[i].isFinite ? min(6, max(-12, gains[i])) : 0
        }
        return copy
    }
}

struct AudioSettingsView: View {
    @Environment(PlaybackController.self) private var playback
    @State private var settings = AudioSettings()
    private var report: LiveSignalPath { playback.audio.signalPath }

    private enum Preset: String, CaseIterable {
        case flat = "Flat", bass = "Bass Boost", vocal = "Vocals", warm = "Warm", bright = "Clarity"

        var gains: [Float] {
            switch self {
            case .flat: [0, 0, 0, 0, 0]
            case .bass: [5, 3, 0, -1, 0]
            case .vocal: [-3, -2, 3, 3, 0]
            case .warm: [2, 3, 0, -1, -2]
            case .bright: [-2, -1, 0, 2, 4]
            }
        }
    }

    var body: some View {
        Form {
            Section {
                Toggle("Bit-perfect-oriented mode", isOn: $settings.integrity)
                Toggle("Prefer direct audio path", isOn: Binding(
                    get: { settings.usesDirectPath }, set: { settings.preferDirect = $0 }
                )).disabled(settings.integrity || settings.processing)
                if settings != AudioSettings() {
                    Button("Restore default settings") { settings = AudioSettings() }
                }
            } header: { Text("Signal integrity") } footer: {
                Text("Integrity mode requests the source sample rate and bypasses EQ. The engine uses the system mixer when the source format and output interface are incompatible.")
            }

            Section {
                Picker("USB DAC rate", selection: $settings.usbRate) {
                    ForEach(AudioSettings.USBRate.allCases, id: \.self) { Text($0.label).tag($0) }
                }.disabled(settings.integrity)
                Picker("I/O buffer", selection: $settings.buffer) {
                    ForEach(AudioSettings.Buffer.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                LabeledContent("Choose audio output") {
                    SystemRoutePicker().frame(width: 44, height: 44).accessibilityLabel("Choose audio output")
                }
            } header: { Text("DAC & output configuration") } footer: {
                Text("With integrity mode off, a fixed sample rate can be requested for USB audio. iOS may select a different rate or buffer for the active route.")
            }

            Section {
                Toggle("Equalizer", isOn: $settings.equalizer).disabled(settings.integrity)
                if settings.integrity {
                    Button("Unlock equalizer") {
                        settings.integrity = false
                        settings.equalizer = true
                    }
                }
                Menu("EQ preset", systemImage: "slider.horizontal.3") {
                    ForEach(Preset.allCases, id: \.self) { preset in
                        Button(preset.rawValue) { settings.gains = preset.gains }
                    }
                }.disabled(settings.integrity || !settings.equalizer)
                ForEach(AudioSettings.frequencies.indices, id: \.self) { i in
                    VStack(alignment: .leading) {
                        Text("\(Int(AudioSettings.frequencies[i])) Hz · \(settings.gains[i], specifier: "%+.0f") dB")
                            .font(.caption.monospacedDigit())
                        Slider(value: $settings.gains[i], in: -12...6, step: 1)
                            .accessibilityLabel("\(Int(AudioSettings.frequencies[i])) Hz EQ band")
                    }.disabled(settings.integrity || !settings.equalizer)
                }
            } header: { Text("Equalizer") } footer: {
                Text("EQ is off by default. Non-flat EQ modifies the audio and applies a −6 dB preamp for headroom.")
            }

            Button("Apply audio settings") { playback.applyAudioSettings(settings) }
                .disabled(playback.busy || settings == playback.settings).accessibilityIdentifier("applyAudioSettings")

            Section("Observed output") {
                LabeledContent("Route", value: playback.audio.route)
                LabeledContent("Requested rate", value: SignalPathView.rate(report.requestedRate))
                LabeledContent("Output sample rate", value: SignalPathView.rate(report.outputRate))
                LabeledContent("Effective I/O buffer", value: SignalPathView.milliseconds(report.bufferDuration))
                LabeledContent("iOS output latency", value: SignalPathView.milliseconds(report.outputLatency))
                NavigationLink("Signal Path") { SignalPathView(showsAudioSettings: false) }
            }
        }.navigationTitle("Audio & Playback").soundlySurface()
            .onAppear { settings = playback.settings }
    }
}
