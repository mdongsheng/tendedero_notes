// Draws the Pinza app icon: a single sheet of note paper held by a wooden
// peg on a thin line, over a warm sunrise gradient.
// Usage: swift scripts/make-icon.swift out.png
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.dropFirst().first ?? "icon.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

func shadow(_ alpha: CGFloat, blur: CGFloat, y: CGFloat) {
    let s = NSShadow()
    s.shadowColor = color(60, 30, 10, alpha)
    s.shadowBlurRadius = blur
    s.shadowOffset = NSSize(width: 0, height: y)
    s.set()
}

// Body, following the macOS icon grid: 824pt square, 100pt margin.
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

ctx.saveGState()
shadow(0.30, blur: 26, y: -12)
color(250, 210, 170).setFill()
shape.fill()
ctx.restoreGState()

ctx.saveGState()
shape.addClip()
NSGradient(colors: [color(255, 200, 92), color(255, 150, 110), color(236, 108, 128)],
           atLocations: [0, 0.55, 1], colorSpace: .sRGB)!
    .draw(in: body, angle: -70)
// Soft light from the top.
NSGradient(colors: [color(255, 255, 255, 0.30), color(255, 255, 255, 0)])!
    .draw(in: NSRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: -90)

// The line, nearly straight: a single note barely weighs it down.
let lineY: CGFloat = 712
let line = NSBezierPath()
line.move(to: NSPoint(x: 60, y: lineY + 20))
line.curve(to: NSPoint(x: 964, y: lineY + 20),
           controlPoint1: NSPoint(x: 360, y: lineY - 20), controlPoint2: NSPoint(x: 664, y: lineY - 20))
ctx.saveGState()
shadow(0.25, blur: 6, y: -4)
color(255, 255, 255, 0.92).setStroke()
line.lineWidth = 9
line.stroke()
ctx.restoreGState()

// The note: a sheet of warm paper, slightly turned.
ctx.saveGState()
ctx.translateBy(x: 512, y: lineY - 6)
ctx.rotate(by: -3.5 * .pi / 180)
let sheet = NSRect(x: -230, y: -500, width: 460, height: 500)
ctx.saveGState()
shadow(0.35, blur: 40, y: -22)
color(255, 252, 244).setFill()
NSBezierPath(roundedRect: sheet, xRadius: 34, yRadius: 34).fill()
ctx.restoreGState()

// Its title and a few lines of writing.
color(48, 44, 52).setFill()
NSBezierPath(roundedRect: NSRect(x: sheet.minX + 56, y: sheet.maxY - 140, width: 250, height: 34),
             xRadius: 17, yRadius: 17).fill()
color(150, 146, 156).setFill()
for (i, w) in [330.0, 300, 342, 210].enumerated() {
    let y = sheet.maxY - 216 - CGFloat(i) * 62
    NSBezierPath(roundedRect: NSRect(x: sheet.minX + 56, y: y, width: CGFloat(w), height: 22),
                 xRadius: 11, yRadius: 11).fill()
}

// The wooden peg gripping the top edge.
let peg = NSRect(x: -26, y: -96, width: 52, height: 168)
ctx.saveGState()
shadow(0.35, blur: 10, y: -6)
NSGradient(colors: [color(196, 140, 86), color(232, 186, 130), color(178, 122, 72)],
           atLocations: [0, 0.45, 1], colorSpace: .sRGB)!
    .draw(in: NSBezierPath(roundedRect: peg, xRadius: 18, yRadius: 18), angle: 0)
ctx.restoreGState()
// The spring, a band of metal across the peg.
NSGradient(colors: [color(150, 150, 158), color(232, 232, 238), color(130, 130, 140)])!
    .draw(in: NSRect(x: peg.minX - 4, y: 4, width: peg.width + 8, height: 18), angle: 0)
// The slot the line passes through.
color(90, 56, 30, 0.6).setFill()
NSBezierPath(roundedRect: NSRect(x: -16, y: 40, width: 32, height: 8), xRadius: 4, yRadius: 4).fill()
ctx.restoreGState()

ctx.restoreGState()
NSGraphicsContext.restoreGraphicsState()

let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: out))
print("Wrote \(out)")
