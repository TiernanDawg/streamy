import AppKit
import CoreGraphics

let side = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                              bytesPerRow: 0, space: colorSpace,
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("Unable to create icon bitmap context")
}
let colors = [
    CGColor(red: 0.025, green: 0.09, blue: 0.07, alpha: 1),
    CGColor(red: 0.08, green: 0.34, blue: 0.20, alpha: 1),
    CGColor(red: 0.34, green: 0.78, blue: 0.42, alpha: 1)
] as CFArray
guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 0.58, 1]) else {
    fatalError("Unable to create icon gradient")
}
context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 1024, y: 0), options: [])

context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.97))
let bag = CGMutablePath()
bag.move(to: CGPoint(x: 250, y: 390))
bag.addQuadCurve(to: CGPoint(x: 300, y: 330), control: CGPoint(x: 250, y: 330))
bag.addLine(to: CGPoint(x: 724, y: 330))
bag.addQuadCurve(to: CGPoint(x: 774, y: 390), control: CGPoint(x: 774, y: 330))
bag.addLine(to: CGPoint(x: 720, y: 740))
bag.addQuadCurve(to: CGPoint(x: 664, y: 790), control: CGPoint(x: 714, y: 790))
bag.addLine(to: CGPoint(x: 360, y: 790))
bag.addQuadCurve(to: CGPoint(x: 304, y: 740), control: CGPoint(x: 306, y: 790))
bag.closeSubpath()
context.addPath(bag)
context.fillPath()

context.setStrokeColor(CGColor(red: 0.08, green: 0.34, blue: 0.20, alpha: 1))
context.setLineWidth(42)
context.setLineCap(.round)
context.move(to: CGPoint(x: 390, y: 410))
context.addLine(to: CGPoint(x: 390, y: 270))
context.addCurve(to: CGPoint(x: 634, y: 270), control1: CGPoint(x: 390, y: 160), control2: CGPoint(x: 634, y: 160))
context.addLine(to: CGPoint(x: 634, y: 410))
context.strokePath()

context.setFillColor(CGColor(red: 0.15, green: 0.62, blue: 0.30, alpha: 1))
let leaf = CGMutablePath()
leaf.move(to: CGPoint(x: 512, y: 610))
leaf.addCurve(to: CGPoint(x: 625, y: 485), control1: CGPoint(x: 600, y: 610), control2: CGPoint(x: 630, y: 530))
leaf.addCurve(to: CGPoint(x: 512, y: 610), control1: CGPoint(x: 510, y: 490), control2: CGPoint(x: 490, y: 560))
leaf.closeSubpath()
context.addPath(leaf)
context.fillPath()

guard let image = context.makeImage() else { fatalError("Unable to render app icon") }
let bitmap = NSBitmapImageRep(cgImage: image)
guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Unable to encode icon") }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
