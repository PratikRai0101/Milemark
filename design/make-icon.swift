// Generates the app icon as a 1024x1024 PNG using SwiftUI/CoreGraphics.
// Run: swift design/make-icon.swift <output.png>
import AppKit
import Foundation

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon.png"
let size = 1024.0

guard let context = CGContext(
    data: nil,
    width: Int(size),
    height: Int(size),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Could not create bitmap context")
}

// Ground: the neutral app grey.
context.setFillColor(CGColor(red: 237 / 255, green: 237 / 255, blue: 236 / 255, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: size, height: size))

// The paper, emerging from the slot. It is drawn first so the slot overlaps
// its top edge, and the sheet reads as coming out of the machine.
let paper = CGRect(x: 272, y: 100, width: 480, height: 600)
context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
context.addPath(CGPath(roundedRect: paper, cornerWidth: 18, cornerHeight: 18, transform: nil))
context.fillPath()

// A route trace printed on the paper: the shape is a plausible recorded run.
context.setStrokeColor(CGColor(red: 25 / 255, green: 26 / 255, blue: 25 / 255, alpha: 1))
context.setLineWidth(28)
context.setLineCap(.round)
context.setLineJoin(.round)
let trace: [CGPoint] = [
    CGPoint(x: 372, y: 300),
    CGPoint(x: 400, y: 420),
    CGPoint(x: 470, y: 520),
    CGPoint(x: 570, y: 560),
    CGPoint(x: 660, y: 500),
    CGPoint(x: 686, y: 390),
    CGPoint(x: 630, y: 300),
    CGPoint(x: 560, y: 250),
    CGPoint(x: 520, y: 180),
    CGPoint(x: 430, y: 170),
    CGPoint(x: 372, y: 240),
    CGPoint(x: 372, y: 300)
]
var tracePath = CGMutablePath()
tracePath.move(to: trace[0])
for point in trace.dropFirst() {
    tracePath.addLine(to: point)
}
context.addPath(tracePath)
context.strokePath()

// The start of the run, marked.
context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
context.fillEllipse(in: CGRect(x: 372 - 27, y: 300 - 27, width: 54, height: 54))
context.setStrokeColor(CGColor(red: 25 / 255, green: 26 / 255, blue: 25 / 255, alpha: 1))
context.setLineWidth(15)
context.strokeEllipse(in: CGRect(x: 372 - 27, y: 300 - 27, width: 54, height: 54))

// The output slot, in front of the paper's top edge.
let slot = CGRect(x: 132, y: 618, width: 760, height: 108)
context.setFillColor(CGColor(red: 25 / 255, green: 26 / 255, blue: 25 / 255, alpha: 1))
context.addPath(CGPath(roundedRect: slot, cornerWidth: 54, cornerHeight: 54, transform: nil))
context.fillPath()

guard let image = context.makeImage() else {
    fatalError("Could not render icon")
}
let rep = NSBitmapImageRep(cgImage: image)
guard let data = rep.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode icon")
}
try data.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
