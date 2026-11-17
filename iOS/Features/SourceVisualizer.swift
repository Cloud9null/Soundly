import SwiftUI
import AVFoundation

/// Bounded source analysis, independent of the playback graph and its samples.
enum SourceEnvelope {
    static func analyze(_ url:URL)throws->[Float] {
        let file = try AVAudioFile(forReading:url)
        guard let buffer = AVAudioPCMBuffer(pcmFormat:file.processingFormat,frameCapacity:4096),file.processingFormat.commonFormat == .pcmFormatFloat32 else { return [] }
        let stride = max(1,Int(ceil(Double(file.length)/20000)))
        var output:[Float] = []; var count = 0; var energy:Double = 0
        while file.framePosition < file.length {
            try Task.checkCancellation(); try file.read(into:buffer,frameCount:4096)
            guard buffer.frameLength > 0, let channels = buffer.floatChannelData else { break }
            for i in 0..<Int(buffer.frameLength) {
                var frameEnergy:Double = 0
                for c in 0..<Int(buffer.format.channelCount) {
                    let value = Double(channels[c][i]); if value.isFinite { frameEnergy += value*value }
                }
                energy += frameEnergy/Double(buffer.format.channelCount); count += 1
                if count == stride { output.append(Float(sqrt(energy/Double(count)))); energy = 0; count = 0 }
            }
        }
        if count > 0 { output.append(Float(sqrt(energy/Double(count)))) }; return output
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
struct SourceVisualizer:View, Animatable {
    var progress:Double = 0
    var animatableData:Double { get { progress } set { progress = newValue } }
    @Environment(PlaybackController.self) private var playback
    @Environment(\.colorScheme) private var scheme
    @AppStorage("visualizerStyle") private var style = "Mirror"
    @AppStorage("visualizerColor") private var tint = "Mint"
    @AppStorage("waveformRed") private var red = 0.18
    @AppStorage("waveformGreen") private var green = 0.8
    @AppStorage("waveformBlue") private var blue = 0.72
    @State private var samples:[Float] = []
    private var colors:[Color] {
        switch tint {
        case "Custom": [Color(red:red,green:green,blue:blue)]
        case "Rose": [.pink,.purple]
        case "Ocean": [.cyan,.blue]
        case "Amber": [.orange,.yellow]
        case "Rainbow": [.pink,.orange,.yellow,.mint,.cyan,.purple]
        default: [.mint,.cyan]
        }
    }
    var body:some View {
        Canvas { context,size in
            let fraction = min(1,max(0,progress))
            let shading = GraphicsContext.Shading.linearGradient(Gradient(colors:colors),startPoint:.zero,endPoint:CGPoint(x:size.width,y:0))
            guard style != "Off",!samples.isEmpty else {
                let rail = Path(roundedRect:CGRect(x:0,y:size.height/2-2,width:size.width,height:4),cornerRadius:2)
                var base = context; base.opacity = 0.14; base.fill(rail,with:.color(.primary))
                var played = context; played.clip(to:Path(CGRect(x:0,y:0,width:size.width*fraction,height:size.height)))
                played.fill(rail,with:shading);return
            }
            // The detailed envelope is computed once on analysis, never on the audio render thread.
            var base = context; base.opacity = scheme == .dark ? 0.32 : 0.26
            Self.draw(&base,size:size,values:samples.map(CGFloat.init),style:style,shading:.color(.primary))
            var played = context
            played.clip(to:Path(CGRect(x:0,y:0,width:size.width*fraction,height:size.height)))
            Self.draw(&played,size:size,values:samples.map(CGFloat.init),style:style,shading:shading)
        }.accessibilityHidden(true)
        .task(id:"\(playback.current?.id.uuidString ?? "")-\(style == "Off")") {
            samples = [];guard style != "Off",let track = playback.current else { return }
            let work = Task.detached { ()throws->[Float] in
                let root = try LibraryPaths.directory("Music")
                let envelope = try SourceEnvelope.analyze(PrivateMusicFile.url(track.filename,in:root))
                return SourceEnvelope.display(envelope,count:180).map(Float.init)
            }
            do {
                let values = try await withTaskCancellationHandler(operation:{try await work.value},onCancel:{work.cancel()})
                guard !Task.isCancelled else { return };samples = values
            } catch { /* A functional seek rail remains when source analysis is unavailable. */ }
        }
    }
    private static func draw(_ context:inout GraphicsContext,size:CGSize,values:[CGFloat],style:String,shading:GraphicsContext.Shading) {
        guard !values.isEmpty else { return }
        let middle = size.height/2
        if style == "Bars" || style == "Orbit" {
            for i in stride(from:0,to:values.count,by:3) {
                let h = max(1,values[i]*(size.height-6))
                let rect = CGRect(x:CGFloat(i)*size.width/CGFloat(values.count),y:(size.height-h)/2,width:max(1,size.width/CGFloat(values.count)*1.7),height:h)
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
    static let names = ["Artwork","Theme","Aurora","Sunset","Ocean","Rose"]
    static func colors(_ name:String)->[Color]? {
        switch name {
        case "Aurora": [.indigo,.purple,.mint]
        case "Sunset": [.pink,.orange,.purple]
        case "Ocean": [.blue,.cyan,.indigo]
        case "Rose": [.pink,.purple,.red]
        default: nil
        }
    }
}
struct VisualizerSettingsView:View {
    @AppStorage("visualizerStyle") private var style = "Mirror"
    @AppStorage("visualizerColor") private var tint = "Mint"
    @AppStorage("playerBackdrop") private var backdrop = "Artwork"
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
                SourceVisualizer(progress:0.55).frame(height:64)
                Picker("Shape",selection:$style) { ForEach(["Off","Wave","Mirror","Bars","Orbit"],id:\.self) { Text($0 == "Orbit" ? "Bars (legacy Orbit)" : $0) } }
                Picker("Color",selection:$tint) { ForEach(["Mint","Rose","Ocean","Amber","Rainbow","Custom"],id:\.self) { Text($0) } }
                ColorPicker("Custom color",selection:custom,supportsOpacity:false)
            }
            Section("Player background") {
                Picker("Background",selection:$backdrop) { ForEach(PlayerBackdrop.names,id:\.self) { Text($0) } }.accessibilityIdentifier("playerBackdropPicker")
            }
            Section {
                Text("Drag the waveform to seek. Its shape comes from the full decoded source, with RMS amplitude scaled to fit the display. It stays still when paused; only the progress moves. This visual scaling does not alter audio and does not measure DAC output. Off keeps a simple seek rail.").font(.footnote)
                Text("Use your iPhone volume buttons or Control Center to adjust volume.").font(.footnote)
            }
        }.navigationTitle("Player appearance").soundlySurface()
    }
}
