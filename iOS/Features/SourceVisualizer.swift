import SwiftUI
import AVFoundation

enum SourceEnvelope {
    static func analyze(_ url:URL)throws->[Float] {
        let file = try AVAudioFile(forReading:url)
        guard let buffer = AVAudioPCMBuffer(pcmFormat:file.processingFormat,frameCapacity:4096),file.processingFormat.commonFormat == .pcmFormatFloat32 else { return [] }
        let stride = max(1,Int(ceil(Double(file.length)/20000)))
        var output:[Float] = []; var count = 0; var peak:Float = 0
        while file.framePosition < file.length {
            try Task.checkCancellation(); try file.read(into:buffer,frameCount:4096)
            guard buffer.frameLength > 0, let channels = buffer.floatChannelData else { break }
            for i in 0..<Int(buffer.frameLength) {
                for c in 0..<Int(buffer.format.channelCount) { let value = abs(channels[c][i]); if value.isFinite { peak = max(peak,value) } }
                count += 1
                if count == stride { output.append(peak); peak = 0; count = 0 }
            }
        }
        if count > 0 { output.append(peak) }; return output
    }
}
struct SourceVisualizer:View {
    @Environment(PlaybackController.self) private var playback
    @AppStorage("visualizerStyle") private var style = "Off"
    @AppStorage("visualizerColor") private var tint = "Mint"
    @State private var samples:[Float] = []
    @State private var note = ""
    private var color:Color { tint == "Rose" ? .pink : tint == "Ocean" ? .cyan : .mint }
    var body:some View {
        VStack(alignment:.leading,spacing:6) {
            if style != "Off" {
                Canvas { context,size in
                    guard !samples.isEmpty else { return }
                    let center = Int(min(1,max(0,playback.audio.elapsed/max(1,playback.audio.duration)))*Double(samples.count-1))
                    var path = Path()
                    for i in 0..<64 {
                        let index = min(samples.count-1,max(0,center+i-32))
                        let amplitude = CGFloat(min(1,samples[index]))
                        let x = CGFloat(i)*size.width/64; let h = amplitude*size.height*0.45
                        if style == "Orbit" {
                            let angle = Double(i)*2*Double.pi/64
                            let radius = size.height*0.22+h*0.4
                            let point = CGPoint(x:size.width/2+CGFloat(cos(angle))*radius,y:size.height/2+CGFloat(sin(angle))*radius)
                            if i == 0 { path.move(to:point) } else { path.addLine(to:point) }
                        } else {
                            path.move(to:CGPoint(x:x,y:size.height/2-h))
                            path.addLine(to:CGPoint(x:x,y:size.height/2+(style == "Mirror" ? h : 0)))
                        }
                    }
                    if style == "Orbit" { path.closeSubpath() }; context.stroke(path,with:.color(color),lineWidth:2)
                }.frame(height:70).accessibilityLabel("Source PCM amplitude envelope, before DSP")
                Text(note).font(.caption2).foregroundStyle(.secondary)
            }
        }.task(id:"\(playback.current?.id.uuidString ?? "")-\(style)") {
            samples = []; guard style != "Off",let track = playback.current else { return }
            note = "Analyzing source PCM…"
            let work = Task.detached { ()throws->[Float] in
                let root = try LibraryPaths.directory("Music")
                return try SourceEnvelope.analyze(PrivateMusicFile.url(track.filename,in:root))
            }
            do {
                let values = try await withTaskCancellationHandler(operation:{try await work.value},onCancel:{work.cancel()})
                guard !Task.isCancelled else { return }; samples = values; note = "Source PCM envelope · pre-DSP · not DAC output"
            } catch { if !Task.isCancelled { note = "Source analysis unavailable" } }
        }
    }
}
struct VisualizerSettingsView:View {
    @AppStorage("visualizerStyle") private var style = "Off"
    @AppStorage("visualizerColor") private var tint = "Mint"
    var body:some View {
        Form {
            Picker("Style",selection:$style) { ForEach(["Off","Bars","Mirror","Orbit"],id:\.self) { Text($0) } }
            Picker("Color",selection:$tint) { ForEach(["Mint","Rose","Ocean"],id:\.self) { Text($0) } }
            Text("Optional local PCM analysis on a background worker. The display follows the source envelope near the playhead, before EQ/system output; it does not measure DAC audio or frequency spectra. Off by default to conserve decoding work. Close the player or select Off to cancel analysis.").font(.footnote)
        }.navigationTitle("Visualizer").soundlySurface()
    }
}
