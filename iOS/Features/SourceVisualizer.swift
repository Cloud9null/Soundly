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
    var progress:Double = 0
    @Environment(PlaybackController.self) private var playback
    @AppStorage("visualizerStyle") private var style = "Off"
    @AppStorage("visualizerColor") private var tint = "Mint"
    @State private var samples:[Float] = []
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
        Canvas { context,size in
            guard style != "Off",!samples.isEmpty else { return }
            let count = 96
            let values:[CGFloat] = (0..<count).map { i in
                let lo = i*samples.count/count
                let hi = max(lo+1,(i+1)*samples.count/count)
                let values = samples[min(lo,samples.count-1)..<min(hi,samples.count)]
                let average = values.reduce(Float(0),+)/Float(max(1,values.count))
                return CGFloat(sqrt(max(0,min(1,average))))
            }
            let shading = GraphicsContext.Shading.linearGradient(Gradient(colors:colors),startPoint:.zero,endPoint:CGPoint(x:size.width,y:0))
            var base = context;base.opacity = 0.22
            Self.draw(&base,size:size,values:values,style:style,shading:shading)
            var played = context
            played.clip(to:Path(CGRect(x:0,y:0,width:size.width*min(1,max(0,progress)),height:size.height)))
            Self.draw(&played,size:size,values:values,style:style,shading:shading)
        }.accessibilityHidden(true)
        .task(id:"\(playback.current?.id.uuidString ?? "")-\(style == "Off")") {
            samples = [];guard style != "Off",let track = playback.current else { return }
            let work = Task.detached { ()throws->[Float] in
                let root = try LibraryPaths.directory("Music")
                return try SourceEnvelope.analyze(PrivateMusicFile.url(track.filename,in:root))
            }
            do {
                let values = try await withTaskCancellationHandler(operation:{try await work.value},onCancel:{work.cancel()})
                guard !Task.isCancelled else { return };samples = values
            } catch { /* Keep the functional seek rail when source analysis is unavailable. */ }
        }
    }
    private static func draw(_ context:inout GraphicsContext,size:CGSize,values:[CGFloat],style:String,shading:GraphicsContext.Shading) {
        let middle = size.height/2
        if style == "Bars" || style == "Orbit" {
            for i in stride(from:0,to:values.count,by:2) {
                let h = max(2,values[i]*(size.height-8))
                let rect = CGRect(x:CGFloat(i)*size.width/CGFloat(values.count),y:(size.height-h)/2,width:max(2,size.width/CGFloat(values.count)),height:h)
                context.fill(Path(roundedRect:rect,cornerRadius:2),with:shading)
            }
            return
        }
        let signs:[CGFloat] = style == "Wave" ? [-1] : [-1,1]
        for sign in signs {
            var line = Path();var previous = CGPoint(x:0,y:middle+sign*values[0]*(middle-4));line.move(to:previous)
            for i in 1..<values.count {
                let point = CGPoint(x:CGFloat(i)*size.width/CGFloat(values.count-1),y:middle+sign*values[i]*(middle-4))
                let x = (previous.x+point.x)/2
                line.addCurve(to:point,control1:CGPoint(x:x,y:previous.y),control2:CGPoint(x:x,y:point.y));previous = point
            }
            var fill = line;fill.addLine(to:CGPoint(x:size.width,y:middle));fill.addLine(to:CGPoint(x:0,y:middle));fill.closeSubpath()
            var soft = context;soft.opacity *= 0.18;soft.fill(fill,with:shading)
            context.stroke(line,with:shading,style:StrokeStyle(lineWidth:1.3,lineCap:.round,lineJoin:.round))
        }
    }
}
struct VisualizerSettingsView:View {
    @AppStorage("visualizerStyle") private var style = "Off"
    @AppStorage("visualizerColor") private var tint = "Mint"
    var body:some View {
        Form {
            Picker("Seek waveform",selection:$style) { ForEach(["Off","Wave","Mirror","Bars","Orbit"],id:\.self) { Text($0 == "Orbit" ? "Bars (legacy Orbit)" : $0) } }
            Picker("Color",selection:$tint) { ForEach(["Mint","Rose","Ocean","Amber","Rainbow"],id:\.self) { Text($0) } }
            Text("The waveform is embedded in the seek rail inside the playback controls. Drag anywhere on it to seek. It represents the full source file, before DSP, with a square-root display scale; it is not a DAC measurement. Off keeps the seek rail without source analysis. Legacy Orbit uses bars in the seek rail.").font(.footnote)
        }.navigationTitle("Visualizer").soundlySurface()
    }
}
