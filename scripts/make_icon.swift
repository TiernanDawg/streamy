import AppKit
import CoreGraphics

let side = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue
guard let context = CGContext(
    data: nil,
    width: side,
    height: side,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: bitmapInfo
) else {
    fatalError("Unable to create icon bitmap context")
}

let colors = [
    CGColor(red: 0.025, green: 0.08, blue: 0.12, alpha: 1),
    CGColor(red: 0.10, green: 0.36, blue: 0.27, alpha: 1),
    CGColor(red: 0.35, green: 0.88, blue: 0.48, alpha: 1)
] as CFArray

let locations: [CGFloat] = [0, 0.58, 1]
guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else {
    fatalError("Unable to create icon gradient")
}
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: side),
    end: CGPoint(x: side, y: 0),
    options: []
)

context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.96))
let play = CGMutablePath()
play.move(to: CGPoint(x: 420, y: 300))
play.addLine(to: CGPoint(x: 720, y: 512))
play.addLine(to: CGPoint(x: 420, y: 724))
play.closeSubpath()
context.addPath(play)
context.fillPath()

context.setStrokeColor(CGColor(red: 0.02, green: 0.12, blue: 0.09, alpha: 0.75))
context.setLineWidth(24)
context.setLineCap(.round)
context.move(to: CGPoint(x: 245, y: 335))
context.addLine(to: CGPoint(x: 245, y: 689))
context.strokePath()

guard let image = context.makeImage() else {
    fatalError("Unable to render app icon")
}
let bitmap = NSBitmapImageRep(cgImage: image)
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode app icon")
}
let output = CommandLine.arguments[1]
try png.write(to: URL(fileURLWithPath: output))
