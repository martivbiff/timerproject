// Renders the app icon (a glowing arc over a night sky) at every size macOS
// wants, then leaves them in an .iconset for iconutil.
import AppKit

let out = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func draw(_ size: Int) -> Data? {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { image.unlockFocus(); return nil }

    // Rounded-rect sky.
    let inset = s * 0.06
    let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let path = CGPath(roundedRect: rect, cornerWidth: s * 0.22, cornerHeight: s * 0.22, transform: nil)
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()

    let space = CGColorSpaceCreateDeviceRGB()
    let sky = CGGradient(colorsSpace: space, colors: [
        CGColor(red: 0.11, green: 0.20, blue: 0.32, alpha: 1),
        CGColor(red: 0.04, green: 0.09, blue: 0.15, alpha: 1),
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])

    // A single wave ridge across the lower third.
    let wave = CGMutablePath()
    wave.move(to: CGPoint(x: rect.minX, y: rect.minY))
    var x = rect.minX
    while x <= rect.maxX {
        let y = rect.minY + s * 0.26 + sin((x - rect.minX) / (s * 0.19)) * s * 0.035
        wave.addLine(to: CGPoint(x: x, y: y))
        x += 1
    }
    wave.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
    wave.closeSubpath()
    ctx.addPath(wave)
    ctx.setFillColor(CGColor(red: 0.22, green: 0.47, blue: 0.70, alpha: 0.45))
    ctx.fillPath()

    // The ring: faint track, bright three-quarter arc.
    let center = CGPoint(x: s / 2, y: s / 2)
    let radius = s * 0.27
    ctx.setLineCap(.round)
    ctx.setLineWidth(s * 0.045)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.12))
    ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.strokePath()

    ctx.setShadow(offset: .zero, blur: s * 0.08,
                  color: CGColor(red: 0.41, green: 0.81, blue: 1, alpha: 0.9))
    ctx.setStrokeColor(CGColor(red: 0.60, green: 0.88, blue: 1, alpha: 1))
    ctx.addArc(center: center, radius: radius,
               startAngle: .pi / 2, endAngle: .pi * 2, clockwise: true)
    ctx.strokePath()
    ctx.restoreGState()

    image.unlockFocus()
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else { return nil }
    return rep.representation(using: .png, properties: [:])
}

for (name, size) in [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
] {
    if let data = draw(size) {
        try? data.write(to: URL(fileURLWithPath: "\(out)/\(name).png"))
    }
}
print("icons written to \(out)")
