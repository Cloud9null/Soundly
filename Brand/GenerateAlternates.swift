import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath:CommandLine.arguments[1])
for name in ["Aurora","Pulse","Orbit","Signature","Glacier","NeonS","Circuit","Hologram","Midnight"] {
    let color = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(data:nil,width:1024,height:1024,bitsPerComponent:8,bytesPerRow:4096,space:color,bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
    let palettes:[String:[[CGFloat]]] = ["Signature":[[0.01,0.015,0.03,1],[0.15,0.18,0.25,1]],"Glacier":[[0.015,0.07,0.12,1],[0.08,0.4,0.5,1]],"NeonS":[[0.025,0.005,0.07,1],[0.19,0.015,0.24,1]],"Circuit":[[0.005,0.015,0.04,1],[0.015,0.12,0.16,1]],"Hologram":[[0.08,0.015,0.18,1],[0.01,0.3,0.24,1]],"Midnight":[[0.025,0.02,0.015,1],[0.16,0.11,0.035,1]],"Aurora":[[0.04,0.02,0.14,1],[0.49,0.22,0.89,1]],"Pulse":[[0.01,0.12,0.13,1],[0.01,0.48,0.43,1]],"Orbit":[[0.01,0.04,0.12,1],[0.06,0.28,0.66,1]]]
    let colors = palettes[name]!.map { CGColor(colorSpace:color,components:$0)! } as CFArray
    let gradient = CGGradient(colorsSpace:color,colors:colors,locations:[0,1])!
    context.drawLinearGradient(gradient,start:CGPoint(x:0,y:1024),end:CGPoint(x:1024,y:0),options:[])
    context.setStrokeColor(CGColor(gray:1,alpha:0.7)); context.setLineWidth(14)
    context.setLineCap(.round); context.setLineJoin(.round)
    if ["Signature","Glacier","NeonS","Circuit","Hologram","Midnight"].contains(name) {
        let neon = name == "Midnight" ? CGColor(red:1,green:0.77,blue:0.33,alpha:1) : CGColor(red:0.2,green:0.92,blue:1,alpha:1)
        if ["Circuit","Hologram","NeonS"].contains(name) {
            context.setStrokeColor(neon.copy(alpha:0.15)!);context.setLineWidth(2)
            for value in stride(from:80,through:944,by:72) {
                context.move(to:CGPoint(x:value,y:0));context.addLine(to:CGPoint(x:value,y:1024))
                context.move(to:CGPoint(x:0,y:value));context.addLine(to:CGPoint(x:1024,y:value));context.strokePath()
            }
            if name == "Circuit" {
                context.setLineWidth(5);context.setStrokeColor(neon.copy(alpha:0.6)!)
                for value in [180,844] {
                    context.move(to:CGPoint(x:value,y:120));context.addLine(to:CGPoint(x:value,y:340));context.addLine(to:CGPoint(x:512,y:512));context.strokePath()
                    context.strokeEllipse(in:CGRect(x:value-12,y:108,width:24,height:24))
                }
            }
        }
        let glyph = CGMutablePath()
        if name == "Circuit" || name == "NeonS" {
            glyph.move(to:CGPoint(x:730,y:770));glyph.addLine(to:CGPoint(x:370,y:770));glyph.addLine(to:CGPoint(x:290,y:680))
            glyph.addLine(to:CGPoint(x:290,y:590));glyph.addLine(to:CGPoint(x:730,y:430));glyph.addLine(to:CGPoint(x:730,y:340))
            glyph.addLine(to:CGPoint(x:650,y:254));glyph.addLine(to:CGPoint(x:290,y:254))
        } else {
            glyph.move(to:CGPoint(x:740,y:730))
            glyph.addCurve(to:CGPoint(x:530,y:804),control1:CGPoint(x:690,y:794),control2:CGPoint(x:610,y:814))
            glyph.addCurve(to:CGPoint(x:292,y:650),control1:CGPoint(x:365,y:804),control2:CGPoint(x:266,y:760))
            glyph.addCurve(to:CGPoint(x:520,y:500),control1:CGPoint(x:292,y:548),control2:CGPoint(x:420,y:538))
            glyph.addCurve(to:CGPoint(x:738,y:350),control1:CGPoint(x:650,y:466),control2:CGPoint(x:738,y:460))
            glyph.addCurve(to:CGPoint(x:500,y:214),control1:CGPoint(x:738,y:230),control2:CGPoint(x:635,y:204))
            glyph.addCurve(to:CGPoint(x:280,y:292),control1:CGPoint(x:395,y:208),control2:CGPoint(x:320,y:238))
        }
        context.setLineWidth(100);context.setLineCap(.round);context.setLineJoin(.round)
        context.saveGState()
        if name != "Signature" { context.setShadow(offset:.zero,blur:35,color:neon.copy(alpha:0.65)) }
        context.setStrokeColor(name == "Midnight" ? neon : CGColor(gray:1,alpha:0.96));context.addPath(glyph);context.strokePath();context.restoreGState()
        if ["NeonS","Hologram"].contains(name) {
            context.setLineWidth(13);context.setStrokeColor(CGColor(red:1,green:0.12,blue:0.68,alpha:0.85))
            context.saveGState();context.translateBy(x:12,y:-10);context.addPath(glyph);context.strokePath();context.restoreGState()
        }
    } else if name == "Pulse" {
        for (i,h) in [120,240,400,560,400,240,120].enumerated() {
            let x = CGFloat(260+i*84)
            context.setLineWidth(38);context.move(to:CGPoint(x:x,y:512-CGFloat(h)/2));context.addLine(to:CGPoint(x:x,y:512+CGFloat(h)/2));context.strokePath()
        }
    } else {
        if name == "Orbit" {
            context.saveGState();context.translateBy(x:512,y:512);context.rotate(by:0.45)
            context.strokeEllipse(in:CGRect(x:-350,y:-220,width:700,height:440));context.restoreGState()
            context.setFillColor(CGColor(red:0.4,green:0.95,blue:1,alpha:1));context.fillEllipse(in:CGRect(x:750,y:640,width:62,height:62))
        } else {
            context.setLineWidth(12);context.move(to:CGPoint(x:220,y:190));context.addLine(to:CGPoint(x:512,y:860));context.addLine(to:CGPoint(x:820,y:190));context.closePath();context.strokePath()
        }
        context.setFillColor(CGColor(gray:1,alpha:0.94));context.move(to:CGPoint(x:415,y:320));context.addLine(to:CGPoint(x:720,y:512));context.addLine(to:CGPoint(x:415,y:704));context.closePath();context.fillPath()
    }
    let image = context.makeImage()!
    for folder in ["AppIcon-\(name).appiconset","IconPreview-\(name).imageset"] {
        let directory = root.appendingPathComponent(folder)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let output = directory.appendingPathComponent("Icon.png")
        let destination = CGImageDestinationCreateWithURL(output as CFURL,UTType.png.identifier as CFString,1,nil)!
        CGImageDestinationAddImage(destination,image,nil);precondition(CGImageDestinationFinalize(destination))
    }
}
