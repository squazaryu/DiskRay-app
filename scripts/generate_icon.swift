import AppKit
import Foundation

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "assets/icon.iconset", isDirectory: true)
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
    let bg = NSBezierPath(roundedRect: rect, xRadius: size * 0.22, yRadius: size * 0.22)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.96, green: 0.98, blue: 1.0, alpha: 1.0),
        NSColor(calibratedRed: 0.80, green: 0.88, blue: 1.0, alpha: 1.0)
    ])!
    gradient.draw(in: bg, angle: -45)

    NSColor(calibratedRed: 0.25, green: 0.45, blue: 0.92, alpha: 0.35).setStroke()
    bg.lineWidth = max(1, size * 0.018)
    bg.stroke()

    let text = "DRay"
    let fontSize = size * 0.26
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
        .foregroundColor: NSColor(calibratedRed: 0.08, green: 0.16, blue: 0.35, alpha: 1),
        .paragraphStyle: paragraph
    ]
    let textRect = NSRect(x: 0, y: size * 0.36, width: size, height: size * 0.3)
    (text as NSString).draw(in: textRect, withAttributes: attrs)

    img.unlockFocus()
    return img
}

for (name, size) in sizes {
    let url = outDir.appendingPathComponent(name)
    let rep = NSBitmapImageRep(data: image(size: size).tiffRepresentation!)!
    let data = rep.representation(using: .png, properties: [:])!
    try data.write(to: url)
}
