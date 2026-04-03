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
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    // Keep icon footprint close to Apple's stock app icons.
    let targetCanvasUsage: CGFloat = 0.834
    let outerInset = size * ((1 - targetCanvasUsage) / 2)
    let iconRect = rect.insetBy(dx: outerInset, dy: outerInset)
    let corner = iconRect.width * 0.225
    let bgPath = NSBezierPath(roundedRect: iconRect, xRadius: corner, yRadius: corner)

    let gradient: NSGradient
    let border: NSColor
    let topGlowColor: NSColor
    let vignetteColor: NSColor
    let textColor: NSColor
    let accentColor: NSColor

    if theme == "dark" {
        gradient = NSGradient(colors: [
            NSColor(calibratedWhite: 0.17, alpha: 1.0),
            NSColor(calibratedWhite: 0.09, alpha: 1.0),
            NSColor(calibratedWhite: 0.04, alpha: 1.0)
        ])!
        border = NSColor(calibratedWhite: 0.98, alpha: 0.23)
        topGlowColor = NSColor.white.withAlphaComponent(0.13)
        vignetteColor = NSColor.black.withAlphaComponent(0.26)
        textColor = NSColor(calibratedWhite: 0.97, alpha: 1.0)
        accentColor = NSColor(calibratedRed: 0.30, green: 0.74, blue: 1.0, alpha: 1.0)
    } else {
        gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.95, green: 0.97, blue: 1.0, alpha: 1.0),
            NSColor(calibratedRed: 0.90, green: 0.94, blue: 1.0, alpha: 1.0),
            NSColor(calibratedRed: 0.93, green: 0.91, blue: 1.0, alpha: 1.0)
        ])!
        border = NSColor(calibratedRed: 0.30, green: 0.45, blue: 0.82, alpha: 0.34)
        topGlowColor = NSColor.white.withAlphaComponent(0.23)
        vignetteColor = NSColor.black.withAlphaComponent(0.08)
        textColor = NSColor(calibratedRed: 0.10, green: 0.22, blue: 0.45, alpha: 1.0)
        accentColor = NSColor(calibratedRed: 0.08, green: 0.46, blue: 0.94, alpha: 1.0)
    }

    gradient.draw(in: bgPath, angle: -35)
    NSGraphicsContext.saveGraphicsState()
    bgPath.addClip()
    let topGlow = NSGradient(colors: [topGlowColor, .clear])!
    topGlow.draw(in: iconRect, angle: 90)
    let vignette = NSGradient(colors: [.clear, vignetteColor])!
    vignette.draw(in: iconRect, angle: 90)
    NSGraphicsContext.restoreGraphicsState()

    border.setStroke()
    bgPath.lineWidth = max(1, size * 0.012)
    bgPath.stroke()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(theme == "dark" ? 0.42 : 0.12)
    shadow.shadowBlurRadius = size * 0.02
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.004)

    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size * 0.235, weight: .heavy),
        .foregroundColor: textColor,
        .paragraphStyle: paragraph,
        .shadow: shadow,
        .kern: 0.2
    ]
    let textRect = NSRect(
        x: iconRect.minX,
        y: iconRect.minY + iconRect.height * 0.34,
        width: iconRect.width,
        height: iconRect.height * 0.40
    )
    ("DRay" as NSString).draw(in: textRect, withAttributes: attrs)

    let accent = NSBezierPath()
    accent.move(to: NSPoint(x: iconRect.minX + iconRect.width * 0.31, y: iconRect.minY + iconRect.height * 0.325))
    accent.line(to: NSPoint(x: iconRect.minX + iconRect.width * 0.69, y: iconRect.minY + iconRect.height * 0.325))
    accent.lineCapStyle = .round
    accent.lineWidth = max(1, size * 0.0135)
    accentColor.withAlphaComponent(theme == "dark" ? 0.85 : 0.74).setStroke()
    accent.stroke()

    image.unlockFocus()
    return image
}

for (name, size) in sizes {
    let url = outDir.appendingPathComponent(name)
    let rep = NSBitmapImageRep(data: image(size: size).tiffRepresentation!)!
    let data = rep.representation(using: .png, properties: [:])!
    try data.write(to: url)
}
