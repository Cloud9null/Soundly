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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("visualizerStyle") private var style = "Off"
    @AppStorage("visualizerColor") private var tint = "Mint"
    @State private var samples:[Float] = []
    @State private var note = ""
    @State private var clock = Date()
    private var colors:[Color] {
        switch tint {
        case "Rose": [.pink,.purple]
        case "Ocean": [.cyan,.blue]
        case "Amber": [.orange,.yellow]
        case "Rainbow": [.pink,.orange,.yellow,.mint,.cyan,.purple]
        default: [.mint,.cyan]
        }
    }
    var body:some View {
        if style != "Off" {
            VStack(spacing:4) {
                TimelineView(.animation(minimumInterval:1.0/30,paused:!playback.audio.playing || reduceMotion)) { timeline in
                    Canvas { context,size in
                        guard !samples.isEmpty else { return }
                        let extra = playback.audio.playing && !reduceMotion ? min(0.3,max(0,timeline.date.timeIntervalSince(clock))) : 0
                        let seconds = playback.audio.elapsed+extra
                        let count = 80
                        let duration = max(1,playback.audio.duration)
                        let values:[CGFloat] = (0..<count).map { i in
                            let time = seconds+(Double(i)/Double(count-1)-0.5)*8
                            guard time >= 0 && time <= duration else { return 0 }
                            let index = min(samples.count-1,Int(time/duration*Double(samples.count-1)))
                            let lo = max(0,index-2);let hi = min(samples.count-1,index+2)
                            let average = samples[lo...hi].reduce(Float(0),+)/Float(hi-lo+1)
                            return CGFloat(sqrt(max(0,min(1,average))))
                        }
                        let gradient = GraphicsContext.Shading.linearGradient(Gradient(colors:colors),startPoint:.zero,endPoint:CGPoint(x:size.width,y:0))
                        let middle = size.height/2
                        if style == "Bars" {
                            for i in stride(from:0,to:count,by:2) {
                                let height = max(2,values[i]*(size.height-6))
                                let rect = CGRect(x:CGFloat(i)*size.width/CGFloat(count),y:(size.height-height)/2,width:max(2,size.width/CGFloat(count)*1.1),height:height)
                                context.fill(Path(roundedRect:rect,cornerRadius:3),with:gradient)
                            }
                        } else if style == "Orbit" {
                            var ring = Path()
                            for i in 0..<count {
                                let angle = Double(i)*2*Double.pi/Double(count)
                                let radius = size.height*0.28+values[i]*size.height*0.17
                                let point = CGPoint(x:size.width/2+CGFloat(cos(angle))*radius,y:middle+CGFloat(sin(angle))*radius)
                                if i == 0 { ring.move(to:point) } else { ring.addLine(to:point) }
                            }
                            ring.closeSubpath();context.stroke(ring,with:gradient,style:StrokeStyle(lineWidth:1.6,lineJoin:.round))
                        } else {
                            func curve(_ sign:CGFloat)->Path {
                                var path = Path();var previous = CGPoint(x:0,y:middle+sign*values[0]*(middle-3))
                                path.move(to:previous)
                                for i in 1..<count {
                                    let point = CGPoint(x:CGFloat(i)*size.width/CGFloat(count-1),y:middle+sign*values[i]*(middle-3))
                                    let mid = (previous.x+point.x)/2
                                    path.addCurve(to:point,control1:CGPoint(x:mid,y:previous.y),control2:CGPoint(x:mid,y:point.y));previous = point
                                }
                                return path
                            }
                            let top = curve(-1)
                            var fill = top
                            fill.addLine(to:CGPoint(x:size.width,y:middle));fill.addLine(to:CGPoint(x:0,y:middle));fill.closeSubpath()
                            context.opacity = 0.16;context.fill(fill,with:gradient);context.opacity = 1
                            context.stroke(top,with:gradient,style:StrokeStyle(lineWidth:1.8,lineCap:.round,lineJoin:.round))
                            if style == "Mirror" {
                                let bottom = curve(1);var lower = bottom
                                lower.addLine(to:CGPoint(x:size.width,y:middle));lower.addLine(to:CGPoint(x:0,y:middle));lower.closeSubpath()
                                context.opacity = 0.16;context.fill(lower,with:gradient);context.opacity = 0.8
                                context.stroke(bottom,with:gradient,style:StrokeStyle(lineWidth:1.5,lineCap:.round,lineJoin:.round))
                            }
                        }
                    }.frame(height:52).accessibilityElement(children:.ignore)
                        .accessibilityLabel("Source PCM amplitude envelope, before DSP")
                        .accessibilityIdentifier("sourceVisualizer")
                }
                HStack {
                    Text(samples.isEmpty ? note : "SOURCE WAVEFORM").font(.system(size:8,weight:.medium)).tracking(1.4).foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        Picker("Style",selection:$style) { ForEach(["Off","Wave","Mirror","Bars","Orbit"],id:\.self) { Text($0) } }
                        Picker("Color",selection:$tint) { ForEach(["Mint","Rose","Ocean","Amber","Rainbow"],id:\.self) { Text($0) } }
                        Text("Source amplitude before DSP. Not a DAC measurement.")
                    } label: { Image(systemName:"slider.horizontal.3").font(.caption).frame(width:44,height:44) }
                        .accessibilityLabel("Visualizer style and color")
                }.frame(height:16)
            }.accessibilityHint("Display only. Source PCM before audio processing, not output verification.")
            .onChange(of:playback.audio.elapsed) { clock = Date() }
            .task(id:"\(playback.current?.id.uuidString ?? "")-\(style == "Off")") {
                samples = [];guard let track = playback.current else { return };note = "ANALYZING SOURCE"
                let work = Task.detached { ()throws->[Float] in
                    let root = try LibraryPaths.directory("Music")
                    return try SourceEnvelope.analyze(PrivateMusicFile.url(track.filename,in:root))
                }
                do {
                    let values = try await withTaskCancellationHandler(operation:{try await work.value},onCancel:{work.cancel()})
                    guard !Task.isCancelled else { return };samples = values;note = "SOURCE WAVEFORM"
                } catch { if !Task.isCancelled { note = "SOURCE ANALYSIS UNAVAILABLE" } }
            }
        }
    }
}
struct VisualizerSettingsView:View {
    @AppStorage("visualizerStyle") private var style = "Off"
    @AppStorage("visualizerColor") private var tint = "Mint"
    var body:some View {
        Form {
            Picker("Style",selection:$style) { ForEach(["Off","Wave","Mirror","Bars","Orbit"],id:\.self) { Text($0) } }
            Picker("Color",selection:$tint) { ForEach(["Mint","Rose","Ocean","Amber","Rainbow"],id:\.self) { Text($0) } }
            Text("A smoothed amplitude envelope from real source PCM, displayed around the playback position with a visual square-root scale. Before DSP; not a spectrum or DAC measurement. Optional background decoding, Off by default. Reduce Motion disables interpolated redraws.").font(.footnote)
        }.navigationTitle("Visualizer").soundlySurface()
    }
}
