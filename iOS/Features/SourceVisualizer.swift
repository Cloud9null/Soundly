import SwiftUI
import AVFoundation

enum WaveformRhythm: String, CaseIterable {
    case balanced = "Balanced", bass = "Bass", dynamics = "Dynamics"

    var description: String {
        switch self {
        case .balanced: "Follows bass and transients."
        case .bass: "Makes low-frequency hits stand out."
        case .dynamics: "Follows changes in the track’s overall energy."
        }
    }
}

/// Bounded source analysis, independent of the playback graph and its samples.
enum SourceEnvelope {
    struct Analysis: Sendable {
        let levels: [Float]
        let pulses: [Float]
        let interval: Double

        var bass: [Float] = []
        var energyScale: Float = 1

        func pulse(at seconds: Double, rhythm: WaveformRhythm = .balanced) -> CGFloat {
            switch rhythm {
            case .balanced: interpolate(pulses, at: seconds)
            case .bass: min(1, 1.2 * interpolate(bass, at: seconds))
            case .dynamics: min(1, interpolate(levels, at: seconds) / CGFloat(energyScale))
            }
        }

        func flow(at seconds: Double, rhythm: WaveformRhythm = .balanced) -> [CGFloat] {
            (0..<48).map { index in
                let x = CGFloat(index) / 47
                let time = seconds - Double(x) * 1.12
                let hit = pulse(at: time, rhythm: rhythm)
                let level = interpolate(levels, at: time)
                let body = min(0.32, sqrt(max(0, level)) * 0.50)
                let taper = pow(1 - x, 0.52)
                return min(1, (body + hit * 1.05) * taper)
            }
        }

        private func interpolate(_ values: [Float], at seconds: Double) -> CGFloat {
            guard seconds.isFinite, seconds >= 0, interval > 0, !values.isEmpty else { return 0 }
            let index = min(seconds / interval, Double(values.count - 1))
            let lower = Int(index)
            let upper = min(lower + 1, values.count - 1)
            let fraction = Float(index - Double(lower))
            return CGFloat(values[lower] + (values[upper] - values[lower]) * fraction)
        }
    }

    static func analyze(_ url: URL) throws -> Analysis {
        let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        let format = file.processingFormat
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8192), format.sampleRate > 0,
              format.channelCount > 0, file.length > 0 else { return Analysis(levels: [], pulses: [], interval: 0) }
        let width = max(1, Int(format.sampleRate / 100), Int(ceil(Double(file.length) / 90_000)))
        let interval = Double(width) / format.sampleRate
        let bassAlpha = Float(1 - exp(-2 * Double.pi * 150 / format.sampleRate))
        var levels: [Float] = [], bass: [Float] = []
        var count = 0
        var energy: Float = 0, bassEnergy: Float = 0
        let channels = Int(format.channelCount)
        var low = [Float](repeating: 0, count: channels)
        while file.framePosition < file.length {
            try Task.checkCancellation()
            try file.read(into: buffer, frameCount: buffer.frameCapacity)
            guard buffer.frameLength > 0, let samples = buffer.floatChannelData else { break }
            for frame in 0..<Int(buffer.frameLength) {
                for channel in 0..<channels {
                    let sample = samples[channel][frame]
                    let value = sample.isFinite ? max(-4, min(4, sample)) : 0
                    low[channel] += bassAlpha * (value - low[channel])
                    energy += value * value
                    bassEnergy += low[channel] * low[channel]
                }
                count += 1
                if count == width {
                    levels.append(sqrt(energy / Float(count * channels)))
                    bass.append(sqrt(bassEnergy / Float(count * channels)))
                    count = 0
                    energy = 0
                    bassEnergy = 0
                }
            }
        }
        if count > 0 {
            levels.append(sqrt(energy / Float(count * channels)))
            bass.append(sqrt(bassEnergy / Float(count * channels)))
        }
        let levelScale = max(0.0001, levels.max() ?? 0)
        let bassScale = max(0.015, bass.max() ?? 0)
        let baselineDecay = Float(exp(-interval / 0.18))
        let releaseDecay = Float(exp(-interval / 0.11))
        var baseline: Float = 0, pulse: Float = 0
        let pulses = zip(levels, bass).map { level, low in
            let signal = 0.36 * (level / levelScale) + 0.64 * (low / bassScale)
            let accent = max(0, signal - baseline)
            baseline = baselineDecay * baseline + (1 - baselineDecay) * signal
            pulse = max(pulse * releaseDecay, min(1, 1.8 * accent + 0.18 * signal))
            return pulse
        }
        return Analysis(
            levels: levels, pulses: pulses, interval: interval,
            bass: bass.map { $0 / bassScale }, energyScale: levelScale
        )
    }
    /// Area-weighted bins retain the timeline even when a very short file has fewer samples than pixels.
    static func display(_ samples:[Float],count:Int)->[CGFloat] {
        guard count > 0,!samples.isEmpty else { return [] }
        let finite = samples.map { $0.isFinite ? max(0,$0) : 0 }
        let scale = max(0.000001,finite.max() ?? 0)
        return (0..<count).map { i in
            let start = Double(i)*Double(finite.count)/Double(count)
            let end = Double(i+1)*Double(finite.count)/Double(count)
            var energy:Double = 0
            for j in Int(start)..<min(finite.count,Int(ceil(end))) {
                let weight = max(0,min(end,Double(j+1))-max(start,Double(j)))
                energy += Double(finite[j])*weight
            }
            return CGFloat(pow(min(1,max(0,energy/(end-start)/Double(scale))),0.7))
        }
    }
}
struct SourceVisualizer:View, @MainActor Animatable {
    var progress:Double = 0
    var allowMotion = true
    var animatableData:Double { get { progress } set { progress = newValue } }
    @Environment(PlaybackController.self) private var playback
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("waveformMotion") private var motionEnabled = true
    @AppStorage("visualizerStyle") private var style = "Flow"
    @AppStorage("visualizerColor") private var tint = "Mint"
    @AppStorage("visualizerRhythm") private var rhythm: WaveformRhythm = .balanced
    @AppStorage("waveformRed") private var red = 0.18
    @AppStorage("waveformGreen") private var green = 0.8
    @AppStorage("waveformBlue") private var blue = 0.72
    @State private var samples: [CGFloat] = []
    @State private var analysis: SourceEnvelope.Analysis?
    private var colors:[Color] {
        switch tint {
        case "Custom": [Color(red:red,green:green,blue:blue)]
        case "Rose": [.pink,.purple]
        case "Ocean": [.cyan,.blue]
        case "Amber": [.orange,.yellow]
        case "Rainbow": [.pink,.orange,.yellow,.mint,.cyan,.purple]
        case "Cobalt": [.blue, .indigo, .purple]
        case "Coral": [.orange, .pink, .red]
        case "Lime": [.green, .mint, .yellow]
        default: [.mint,.cyan]
        }
    }
    var body: some View {
        let audio = playback.audio
        let moving = allowMotion && motionEnabled && !reduceMotion && scenePhase == .active
            && style != "Off" && analysis != nil && audio.playing && !playback.busy
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !moving)) { _ in
            let elapsed = audio.elapsed + max(0, min(0.55, ProcessInfo.processInfo.systemUptime - audio.observedAt))
            let time = min(audio.duration, moving ? elapsed : audio.elapsed)
            if ["Flow", "Ribbon", "Pulse Bars"].contains(style),
               motionEnabled, !reduceMotion, let analysis, !samples.isEmpty {
                let moment = allowMotion ? time : min(audio.duration, progress * audio.duration)
                flow(values: analysis.flow(at: moment, rhythm: rhythm))
            } else {
                let pulse = moving ? analysis?.pulse(at: time, rhythm: rhythm) ?? 0 : 0
                waveform(pulse: pulse)
            }
        }
        .accessibilityHidden(true)
        .task(id: "\(playback.current?.id.uuidString ?? "")-\(style == "Off")") {
            samples = []
            analysis = nil
            guard style != "Off", let track = playback.current else { return }
            let work = Task.detached(priority: .utility) {
                let root = try LibraryPaths.directory("Music")
                let analysis = try SourceEnvelope.analyze(PrivateMusicFile.url(track.filename, in: root))
                return (analysis, SourceEnvelope.display(analysis.levels, count: 180))
            }
            do {
                let result = try await withTaskCancellationHandler(operation: { try await work.value }, onCancel: { work.cancel() })
                guard !Task.isCancelled else { return }
                analysis = result.0
                samples = result.1
            } catch { /* The simple seek rail stays available. */ }
        }
    }

    private func flow(values: [CGFloat]) -> some View {
        Canvas { context, size in
            let baseline = max(6, size.height - 5)
            let rail = Path(roundedRect: CGRect(x: 0, y: baseline, width: size.width, height: 2.5), cornerRadius: 1.25)
            context.fill(rail, with: .color(.primary.opacity(0.16)))
            let palette = [colors.first ?? .mint, colors.last ?? .cyan]
            let railEnd = size.width * min(1, max(0, progress))
            let played = Path(roundedRect: CGRect(x: 0, y: baseline, width: railEnd, height: 2.5), cornerRadius: 1.25)
            context.fill(played, with: .linearGradient(Gradient(colors: palette), startPoint: .zero,
                                                       endPoint: CGPoint(x: size.width, y: 0)))

            let gradient = GraphicsContext.Shading.linearGradient(Gradient(colors: colors),
                startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0))
            if style == "Ribbon" || style == "Pulse Bars" {
                let signalSize = CGSize(width: size.width, height: max(6, baseline - 3))
                var signal = context
                let fade = GraphicsContext.Shading.linearGradient(
                    Gradient(colors: [colors.first ?? .mint, colors.last ?? .cyan, .clear]),
                    startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)
                )
                Self.draw(&signal, size: signalSize, values: values, style: style, shading: fade)
                return
            }
            let points = values.enumerated().map { index, value in
                CGPoint(x: size.width * CGFloat(index) / CGFloat(values.count - 1),
                        y: baseline - 3 - value * (baseline - 6))
            }
            guard let first = points.first else { return }
            var line = Path()
            line.move(to: first)
            var previous = first
            for point in points.dropFirst() {
                let middle = (previous.x + point.x) / 2
                line.addCurve(to: point, control1: CGPoint(x: middle, y: previous.y),
                              control2: CGPoint(x: middle, y: point.y))
                previous = point
            }
            var fill = line
            fill.addLine(to: CGPoint(x: size.width, y: baseline - 3))
            fill.addLine(to: CGPoint(x: 0, y: baseline - 3))
            fill.closeSubpath()
            let shade = palette.first ?? .mint
            context.fill(fill, with: .linearGradient(Gradient(colors: [shade.opacity(0.46), shade.opacity(0.035)]),
                                                     startPoint: .zero, endPoint: CGPoint(x: 0, y: baseline)))
            if scheme == .dark {
                var glow = context
                glow.addFilter(.blur(radius: 3))
                glow.opacity = 0.5
                glow.stroke(line, with: gradient, style: StrokeStyle(lineWidth: 2.8, lineCap: .round))
            }
            context.stroke(line, with: gradient, style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
        }
    }

    private func waveform(pulse: CGFloat) -> some View {
        Canvas { context, size in
            let fraction = min(1, max(0, progress))
            let end = CGPoint(x: size.width, y: 0)
            let shading = GraphicsContext.Shading.linearGradient(Gradient(colors: colors), startPoint: .zero, endPoint: end)
            let playedMask = Path(CGRect(x: 0, y: 0, width: size.width * fraction, height: size.height))
            var played = context
            played.clip(to: playedMask)
            guard style != "Off", !samples.isEmpty else {
                let rail = Path(roundedRect: CGRect(x: 0, y: size.height / 2 - 2, width: size.width, height: 4), cornerRadius: 2)
                context.fill(rail, with: .color(.primary.opacity(0.14)))
                played.fill(rail, with: shading)
                return
            }
            let values = samples.enumerated().map { index, amplitude in
                let point = Double(index) / Double(max(1, samples.count - 1))
                let distance = abs(point - fraction) / 0.23
                let focus = CGFloat(max(0, 1 - distance))
                return min(1, amplitude * (0.58 + 1.75 * pulse * (0.36 + 0.64 * focus)))
            }
            var base = context
            base.opacity = scheme == .dark ? 0.32 : 0.26
            Self.draw(&base, size: size, values: values, style: style, shading: .color(.primary))
            Self.draw(&played, size: size, values: values, style: style, shading: shading)
            if pulse > 0.015 {
                let x = size.width * fraction
                let glow = GraphicsContext.Shading.linearGradient(
                    Gradient(colors: [.clear, (colors.last ?? .mint).opacity(0.8 * pulse), .clear]),
                    startPoint: CGPoint(x: x - size.width * 0.19, y: 0),
                    endPoint: CGPoint(x: x + size.width * 0.19, y: 0), options: [])
                var halo = context
                halo.addFilter(.blur(radius: 2.5))
                Self.draw(&halo, size: size, values: values, style: style, shading: glow)
            }
        }
    }
    private static func draw(_ context:inout GraphicsContext,size:CGSize,values:[CGFloat],style:String,shading:GraphicsContext.Shading) {
        guard !values.isEmpty else { return }
        let middle = size.height/2
        if style == "Bars" || style == "Orbit" || style == "Pulse Bars" {
            let step = style == "Pulse Bars" && values.count < 60 ? 1 : 3
            for i in stride(from: 0, to: values.count, by: step) {
                let h = max(1, values[i] * (size.height - 6))
                let unit = size.width / CGFloat(values.count)
                let rect = CGRect(x: CGFloat(i) * unit, y: (size.height - h) / 2,
                                  width: max(1, unit * CGFloat(step) * 0.58), height: h)
                context.fill(Path(roundedRect:rect,cornerRadius:2),with:shading)
            }
            return
        }
        func edge(_ sign:CGFloat,reverse:Bool)->Path {
            let indices = reverse ? Array(values.indices.reversed()) : Array(values.indices)
            var line = Path(); var previous = CGPoint.zero
            for (offset,i) in indices.enumerated() {
                let point = CGPoint(x:CGFloat(i)*size.width/CGFloat(max(1,values.count-1)),y:middle+sign*values[i]*(middle-3))
                if offset == 0 { line.move(to:point) }
                else {
                    let x = (previous.x+point.x)/2
                    line.addCurve(to:point,control1:CGPoint(x:x,y:previous.y),control2:CGPoint(x:x,y:point.y))
                };previous = point
            };return line
        }
        let upper = edge(-1,reverse:false)
        if style == "Ribbon" {
            context.stroke(upper, with: shading, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            context.stroke(edge(1, reverse: false), with: shading, style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            return
        }
        var silhouette = upper
        if style == "Wave" { silhouette.addLine(to:CGPoint(x:size.width,y:middle));silhouette.addLine(to:CGPoint(x:0,y:middle)) }
        else {
            // Join both edges in a single filled shape; no separate floating visualizer.
            silhouette.addLine(to:CGPoint(x:size.width,y:middle+values[values.count-1]*(middle-3)))
            var previous = CGPoint(x:size.width,y:middle+values[values.count-1]*(middle-3))
            for i in values.indices.reversed().dropFirst() {
                let point = CGPoint(x:CGFloat(i)*size.width/CGFloat(max(1,values.count-1)),y:middle+values[i]*(middle-3))
                let x = (previous.x+point.x)/2
                silhouette.addCurve(to:point,control1:CGPoint(x:x,y:previous.y),control2:CGPoint(x:x,y:point.y));previous = point
            }
        }
        silhouette.closeSubpath();context.fill(silhouette,with:shading)
    }
}
enum PlayerBackdrop {
    static let names = ["Artwork", "Theme", "Aurora", "Sunset", "Ocean", "Rose", "Haze", "Garden"]
    static func colors(_ name:String)->[Color]? {
        switch name {
        case "Aurora": [.indigo,.purple,.mint]
        case "Sunset": [.pink,.orange,.purple]
        case "Ocean": [.blue,.cyan,.indigo]
        case "Rose": [.pink,.purple,.red]
        case "Haze": [.cyan, .indigo, .pink]
        case "Garden": [.mint, .green, .yellow]
        default: nil
        }
    }
}
struct VisualizerSettingsView:View {
    @AppStorage("visualizerStyle") private var style = "Flow"
    @AppStorage("visualizerColor") private var tint = "Mint"
    @AppStorage("visualizerRhythm") private var rhythm: WaveformRhythm = .balanced
    @AppStorage("playerBackdrop") private var backdrop = "Artwork"
    @AppStorage("waveformMotion") private var motion = true
    @AppStorage("waveformRed") private var red = 0.18
    @AppStorage("waveformGreen") private var green = 0.8
    @AppStorage("waveformBlue") private var blue = 0.72
    private var custom:Binding<Color> {
        Binding(get:{Color(red:red,green:green,blue:blue)},set:{ value in
            var r:CGFloat = 0,g:CGFloat = 0,b:CGFloat = 0,a:CGFloat = 0
            if UIColor(value).getRed(&r,green:&g,blue:&b,alpha:&a) { red = Double(r);green = Double(g);blue = Double(b);tint = "Custom" }
        })
    }
    var body:some View {
        Form {
            Section("Waveform") {
                SourceVisualizer(progress:0.55, allowMotion:false).frame(height:64)
                Toggle("Move with the music", isOn: $motion)
                Picker("Shape", selection: $style) {
                    ForEach(["Flow", "Ribbon", "Pulse Bars", "Wave", "Mirror", "Bars", "Off", "Orbit"], id: \.self) {
                        Text($0 == "Orbit" ? "Bars (legacy Orbit)" : $0)
                    }
                }
                Picker("Rhythm response", selection: $rhythm) {
                    ForEach(WaveformRhythm.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.disabled(!motion || style == "Off")
                if motion && style != "Off" {
                    Text(rhythm.description).font(.footnote).foregroundStyle(.secondary)
                }
                Picker("Color", selection: $tint) {
                    ForEach(["Mint", "Rose", "Ocean", "Amber", "Rainbow", "Cobalt", "Coral", "Lime", "Custom"], id: \.self) { Text($0) }
                }
                ColorPicker("Custom color",selection:custom,supportsOpacity:false)
            }
            Section("Player background") {
                Picker("Background",selection:$backdrop) { ForEach(PlayerBackdrop.names,id:\.self) { Text($0) } }.accessibilityIdentifier("playerBackdropPicker")
            }
            Section {
                Text("Drag across the waveform to seek. Flow, Ribbon and Pulse Bars show a short trail of the music as it plays.").font(.footnote)
                Text("Use your iPhone volume buttons or Control Center to adjust volume.").font(.footnote)
            }
        }.navigationTitle("Player appearance").soundlySurface()
    }
}
