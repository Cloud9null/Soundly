#if DEBUG
import SwiftUI
import SwiftData
import CryptoKit

/// Real locally generated PCM/artwork for UI tests only. Entire implementation is absent from Release.
@MainActor enum DebugFixtures {
    static var enabled:Bool { ProcessInfo.processInfo.arguments.contains("--soundly-fixtures") }
    static func prepare(_ db:ModelContainer) async throws {
        let duplicate = ProcessInfo.processInfo.arguments.contains("--soundly-duplicates")
        let items = try await Task.detached {
            let music = try LibraryPaths.directory("Music")
            let state = try LibraryPaths.base().appendingPathComponent("Playback.json")
            if FileManager.default.fileExists(atPath:state.path) { try FileManager.default.removeItem(at:state) }
            let frames = 44100*60
            var data = Data()
            func number(_ value:Int,_ bytes:Int) { for i in 0..<bytes { data.append(UInt8(truncatingIfNeeded:value >> (i*8))) } }
            data.append(contentsOf:"RIFF".utf8); number(36+frames*6,4); data.append(contentsOf:"WAVEfmt ".utf8)
            number(16,4); number(1,2); number(2,2); number(44100,4); number(44100*6,4); number(6,2); number(24,2)
            data.append(contentsOf:"data".utf8); number(frames*6,4)
            var pcm = Data(count:frames*6)
            pcm.withUnsafeMutableBytes { buffer in
                let p = buffer.bindMemory(to:UInt8.self)
                for i in 0..<frames {
                    let a:Int32 = i%2 == 0 ? 4096 : -2048
                    for channel in 0..<2 {
                        let value = channel == 0 ? a : -a
                        for byte in 0..<3 { p[i*6+channel*3+byte] = UInt8(truncatingIfNeeded:value >> (byte*8)) }
                    }
                }
            }
            data.append(pcm)
            var items:[ImportedSong] = []
            for i in 1...3 {
                var bytes = data
                if !duplicate || i == 3 { bytes[44] = UInt8(i) }
                let name = "ui-reference-\(i).wav"
                try bytes.write(to:music.appendingPathComponent(name))
                var metadata = MusicMetadata(title:"Reference \(i)",artist:"Soundly Test Audio",album:"Original PCM references")
                metadata.duration = 60; metadata.rate = 44100; metadata.bits = 24; metadata.channels = 2; metadata.codec = "PCM"
                let hash = SHA256.hash(data:bytes).map { String(format:"%02x",$0) }.joined()
                items.append(ImportedSong(hash:duplicate ? "legacy-ui-record-\(i)" : hash,filename:name,metadata:metadata,size:Int64(bytes.count),artwork:"ui-reference-\(i).jpg",folder:"UI test references"))
            }
            return items
        }.value
        for (index,item) in items.enumerated() {
            let image = UIGraphicsImageRenderer(size:CGSize(width:512,height:512)).image { renderer in
                let context = renderer.cgContext
                let colors = [UIColor(red:0.04,green:0.08,blue:0.20,alpha:1).cgColor,UIColor(red:0.29,green:0.19+CGFloat(index)*0.08,blue:0.65,alpha:1).cgColor] as CFArray
                if let gradient = CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colors,locations:nil) {
                    context.drawLinearGradient(gradient,start:CGPoint(x:0,y:0),end:CGPoint(x:512,y:512),options:[])
                }
                UIColor.white.withAlphaComponent(0.28).setStroke()
                for line in 0..<8 { let rect = CGRect(x:80+line*12,y:80+line*12,width:352-line*24,height:352-line*24); context.strokeEllipse(in:rect) }
                let title = "REFERENCE \(index+1)" as NSString
                title.draw(at:CGPoint(x:36,y:400),withAttributes:[.font:UIFont.systemFont(ofSize:32,weight:.bold),.foregroundColor:UIColor.white])
                ("SOUNDLY · TEST PCM" as NSString).draw(at:CGPoint(x:36,y:448),withAttributes:[.font:UIFont.systemFont(ofSize:17,weight:.medium),.foregroundColor:UIColor.white.withAlphaComponent(0.8)])
            }
            if let jpeg = image.jpegData(compressionQuality:0.9),let name = item.artwork { try jpeg.write(to:LibraryPaths.directory("Artwork").appendingPathComponent(name)) }
            let song = Song(item); song.dateAdded = Date(timeIntervalSince1970:Double(index)); db.mainContext.insert(song)
        }
        try db.mainContext.save()
        UserDefaults.standard.set("amethyst",forKey:"theme")
    }
}

struct DebugPresentation:ViewModifier {
    @ViewBuilder func body(content:Content)->some View {
        if ProcessInfo.processInfo.arguments.contains("--soundly-large-type") { content.dynamicTypeSize(.accessibility2) }
        else { content }
    }
}
#endif
