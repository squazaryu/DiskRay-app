import AppKit
import Foundation

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "assets/icon.iconset", isDirectory: true)
let theme = CommandLine.arguments.count > 2 ? CommandLine.arguments[2].lowercased() : "light"
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func image(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let bg = NSBezierPath(roundedRect: rect, xRadius: size * 0.24, yRadius: size * 0.24)
    let inset = rect.insetBy(dx: size * 0.04, dy: size * 0.04)
    let inner = NSBezierPath(roundedRect: inset, xRadius: size * 0.18, yRadius: size * 0.18)

    let gradient: NSGradient
    let innerGlow: NSColor
    let stroke: NSColor
    let glyphColor: NSColor
    let accentColor: NSColor
    if theme == "dark" {
        gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.12, green: 0.16, blue: 0.30, alpha: 1.0),
            NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.19, alpha: 1.0),
            NSColor(calibratedRed: 0.09, green: 0.06, blue: 0.22, alpha: 1.0)
        ])!
        innerGlow = NSColor(calibratedRed: 0.70, green: 0.88, blue: 1.0, alpha: 0.18)
        stroke = NSColor(calibratedRed: 0.62, green: 0.78, blue: 1.0, alpha: 0.52)
        glyphColor = NSColor(calibratedRed: 0.90, green: 0.95, blue: 1.0, alpha: 1.0)
        accentColor = NSColor(calibratedRed: 0.31, green: 0.72, blue: 1.0, alpha: 1.0)
    } else {
        gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.92, green: 0.96, blue: 1.0, alpha: 1.0),
            NSColor(calibratedRed: 0.74, green: 0.86, blue: 1.0, alpha: 1.0),
            NSColor(calibratedRed: 0.83, green: 0.78, blue: 1.0, alpha: 1.0)
        ])!
        innerGlow = NSColor(calibratedRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.32)
        stroke = NSColor(calibratedRed: 0.28, green: 0.49, blue: 0.93, alpha: 0.42)
        glyphColor = NSColor(calibratedRed: 0.05, green: 0.16, blue: 0.43, alpha: 1.0)
        accentColor = NSColor(calibratedRed: 0.08, green: 0.46, blue: 0.95, alpha: 1.0)
    }

    gradient.draw(in: bg, angle: -38)

    innerGlow.setFill()
    inner.fill()

    stroke.setStroke()
    bg.lineWidth = max(1, size * 0.018)
    bg.stroke()

    let coreRect = NSRect(
        x: size * 0.22,
        y: size * 0.18,
        width: size * 0.56,
        height: size * 0.64
    )
    let corePath = NSBezierPath(roundedRect: coreRect, xRadius: size * 0.18, yRadius: size * 0.18)
    NSColor.white.withAlphaComponent(theme == "dark" ? 0.10 : 0.26).setFill()
    corePath.fill()
    NSColor.white.withAlphaComponent(theme == "dark" ? 0.20 : 0.34).setStroke()
    corePath.lineWidth = max(1, size * 0.008)
    corePath.stroke()

    let text = "D"
    let fontSize = size * 0.36
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(theme == "dark" ? 0.32 : 0.12)
    shadow.shadowBlurRadius = size * 0.02
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.006)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
        .foregroundColor: glyphColor,
        .paragraphStyle: paragraph,
        .shadow: shadow
    ]
    let textRect = NSRect(x: 0, y: size * 0.34, width: size, height: size * 0.3)
    (text as NSString).draw(in: textRect, withAttributes: attrs)

    let ray = NSBezierPath()
    ray.move(to: NSPoint(x: size * 0.62, y: size * 0.34))
    ray.line(to: NSPoint(x: size * 0.78, y: size * 0.22))
    ray.lineCapStyle = .round
    ray.lineWidth = max(1.5, size * 0.035)
    accentColor.setStroke()
    ray.stroke()

    let rayDotRect = NSRect(x: size * 0.755, y: size * 0.205, width: size * 0.05, height: size * 0.05)
    let rayDot = NSBezierPath(ovalIn: rayDotRect)
    accentColor.setFill()
    rayDot.fill()

    img.unlockFocus()
    return img
}

for (name, size) in sizes {
    let url = outDir.appendingPathComponent(name)
    let rep = NSBitmapImageRep(data: image(size: size).tiffRepresentation!)!
    let data = rep.representation(using: .png, properties: [:])!
    try data.write(to: url)
}
