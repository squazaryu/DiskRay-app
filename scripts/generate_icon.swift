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
    let corner = size * 0.23
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: corner, yRadius: corner)

    let gradient: NSGradient
    let border: NSColor
    let panelFill: NSColor
    let textColor: NSColor
    let accentColor: NSColor

    if theme == "dark" {
        gradient = NSGradient(colors: [
            NSColor(calibratedWhite: 0.13, alpha: 1.0),
            NSColor(calibratedWhite: 0.08, alpha: 1.0),
            NSColor(calibratedWhite: 0.03, alpha: 1.0)
        ])!
        border = NSColor(calibratedWhite: 0.92, alpha: 0.14)
        panelFill = NSColor(calibratedWhite: 1.0, alpha: 0.06)
        textColor = NSColor(calibratedWhite: 0.97, alpha: 1.0)
        accentColor = NSColor(calibratedRed: 0.30, green: 0.74, blue: 1.0, alpha: 1.0)
    } else {
        gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.95, green: 0.97, blue: 1.0, alpha: 1.0),
            NSColor(calibratedRed: 0.90, green: 0.94, blue: 1.0, alpha: 1.0),
            NSColor(calibratedRed: 0.93, green: 0.90, blue: 1.0, alpha: 1.0)
        ])!
        border = NSColor(calibratedRed: 0.31, green: 0.46, blue: 0.80, alpha: 0.30)
        panelFill = NSColor.white.withAlphaComponent(0.32)
        textColor = NSColor(calibratedRed: 0.10, green: 0.22, blue: 0.45, alpha: 1.0)
        accentColor = NSColor(calibratedRed: 0.08, green: 0.46, blue: 0.94, alpha: 1.0)
    }

    gradient.draw(in: bgPath, angle: -35)

    let panelRect = rect.insetBy(dx: size * 0.12, dy: size * 0.18)
    let panel = NSBezierPath(roundedRect: panelRect, xRadius: size * 0.13, yRadius: size * 0.13)
    panelFill.setFill()
    panel.fill()

    border.setStroke()
    bgPath.lineWidth = max(1, size * 0.012)
    bgPath.stroke()

    NSColor.white.withAlphaComponent(theme == "dark" ? 0.12 : 0.24).setStroke()
    panel.lineWidth = max(1, size * 0.007)
    panel.stroke()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(theme == "dark" ? 0.42 : 0.12)
    shadow.shadowBlurRadius = size * 0.02
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.004)

    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size * 0.20, weight: .heavy),
        .foregroundColor: textColor,
        .paragraphStyle: paragraph,
        .shadow: shadow,
        .kern: 0.2
    ]
    let textRect = NSRect(x: 0, y: size * 0.38, width: size, height: size * 0.28)
    ("DRay" as NSString).draw(in: textRect, withAttributes: attrs)

    let accent = NSBezierPath()
    accent.move(to: NSPoint(x: size * 0.30, y: size * 0.36))
    accent.line(to: NSPoint(x: size * 0.70, y: size * 0.36))
    accent.lineCapStyle = .round
    accent.lineWidth = max(1, size * 0.016)
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
