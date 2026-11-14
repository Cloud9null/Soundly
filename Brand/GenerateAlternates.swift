import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath:CommandLine.arguments[1])
for name in ["Aurora","Pulse","Orbit"] {
    let color = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(data:nil,width:1024,height:1024,bitsPerComponent:8,bytesPerRow:4096,space:color,bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
    let palettes:[String:[[CGFloat]]] = ["Aurora":[[0.04,0.02,0.14,1],[0.49,0.22,0.89,1]],"Pulse":[[0.01,0.12,0.13,1],[0.01,0.48,0.43,1]],"Orbit":[[0.01,0.04,0.12,1],[0.06,0.28,0.66,1]]]
    let colors = palettes[name]!.map { CGColor(colorSpace:color,components:$0)! } as CFArray
    let gradient = CGGradient(colorsSpace:color,colors:colors,locations:[0,1])!
    context.drawLinearGradient(gradient,start:CGPoint(x:0,y:1024),end:CGPoint(x:1024,y:0),options:[])
    context.setStrokeColor(CGColor(gray:1,alpha:0.7)); context.setLineWidth(14)
    context.setLineCap(.round); context.setLineJoin(.round)
    if name == "Pulse" {
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
