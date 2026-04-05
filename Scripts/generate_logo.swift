import AppKit
import Foundation

extension NSColor {
    convenience init(hex: Int, alpha: CGFloat = 1.0) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255.0
        let green = CGFloat((hex >> 8) & 0xFF) / 255.0
        let blue = CGFloat(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [NSPoint](repeating: .zero, count: 3)

        for index in 0..<elementCount {
            switch element(at: index, associatedPoints: &points) {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }

        return path
    }
}

func drawRoundedRect(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawSparkle(center: CGPoint, outerRadius: CGFloat, innerRadius: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    let points = 8

    for index in 0..<points {
        let angle = (Double(index) * (.pi / 4.0)) - (.pi / 2.0)
        let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
        let x = center.x + CGFloat(cos(angle)) * radius
        let y = center.y + CGFloat(sin(angle)) * radius
        let point = CGPoint(x: x, y: y)

        if index == 0 {
            path.move(to: point)
        } else {
            path.line(to: point)
        }
    }

    path.close()
    return path
}

func drawCornerAccent(in context: CGContext, rect: CGRect, lineWidth: CGFloat, color: NSColor, mirrored: Bool = false) {
    let insetRect = rect.insetBy(dx: 26, dy: 26)
    let radius: CGFloat = 42

    let path = CGMutablePath()

    if !mirrored {
        path.move(to: CGPoint(x: insetRect.minX + 72, y: insetRect.maxY))
        path.addLine(to: CGPoint(x: insetRect.minX + radius, y: insetRect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: insetRect.minX, y: insetRect.maxY - radius),
            control: CGPoint(x: insetRect.minX, y: insetRect.maxY)
        )
        path.addLine(to: CGPoint(x: insetRect.minX, y: insetRect.maxY - 110))
    } else {
        path.move(to: CGPoint(x: insetRect.maxX - 72, y: insetRect.minY))
        path.addLine(to: CGPoint(x: insetRect.maxX - radius, y: insetRect.minY))
        path.addQuadCurve(
            to: CGPoint(x: insetRect.maxX, y: insetRect.minY + radius),
            control: CGPoint(x: insetRect.maxX, y: insetRect.minY)
        )
        path.addLine(to: CGPoint(x: insetRect.maxX, y: insetRect.minY + 110))
    }

    context.saveGState()
    context.addPath(path)
    context.setStrokeColor(color.cgColor)
    context.setLineWidth(lineWidth)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.strokePath()
    context.restoreGState()
}

func drawLogo(in rect: NSRect) {
    let s = rect.width / 1024.0
    let context = NSGraphicsContext.current!.cgContext

    let canvas = CGRect(x: 0, y: 0, width: rect.width, height: rect.height)

    let backgroundRect = canvas.insetBy(dx: 44 * s, dy: 44 * s)
    let backgroundPath = drawRoundedRect(backgroundRect, radius: 230 * s)

    context.saveGState()
    context.addPath(backgroundPath.cgPath)
    context.clip()

    let backgroundGradient = NSGradient(colors: [
        NSColor(hex: 0x0C1322),
        NSColor(hex: 0x10253D),
        NSColor(hex: 0x122E47)
    ])!
    backgroundGradient.draw(in: backgroundPath, angle: -55)

    let glowOne = NSBezierPath(ovalIn: CGRect(x: 170 * s, y: 280 * s, width: 680 * s, height: 520 * s))
    NSColor(hex: 0x2BCBBA, alpha: 0.16).setFill()
    glowOne.fill()

    let glowTwo = NSBezierPath(ovalIn: CGRect(x: 430 * s, y: 470 * s, width: 360 * s, height: 280 * s))
    NSColor(hex: 0xF8C35E, alpha: 0.14).setFill()
    glowTwo.fill()

    let shadowGradient = NSGradient(colors: [
        NSColor(calibratedWhite: 0.0, alpha: 0.00),
        NSColor(calibratedWhite: 0.0, alpha: 0.18)
    ])!
    shadowGradient.draw(in: backgroundPath, relativeCenterPosition: NSPoint(x: 0.55, y: -0.6))

    backgroundPath.lineWidth = 10 * s
    NSColor.white.withAlphaComponent(0.09).setStroke()
    backgroundPath.stroke()
    context.restoreGState()

    let frameRect = CGRect(x: 190 * s, y: 210 * s, width: 644 * s, height: 604 * s)
    drawCornerAccent(
        in: context,
        rect: frameRect,
        lineWidth: 26 * s,
        color: NSColor(hex: 0x67E8F9, alpha: 0.42)
    )
    drawCornerAccent(
        in: context,
        rect: frameRect,
        lineWidth: 26 * s,
        color: NSColor(hex: 0xF8C35E, alpha: 0.34),
        mirrored: true
    )

    let keyShadowRect = CGRect(x: 252 * s, y: 238 * s, width: 520 * s, height: 394 * s)
    let keyShadowPath = drawRoundedRect(keyShadowRect, radius: 158 * s)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -28 * s), blur: 56 * s, color: NSColor.black.withAlphaComponent(0.24).cgColor)
    NSColor(hex: 0x0B1A2B, alpha: 0.82).setFill()
    keyShadowPath.fill()
    context.restoreGState()

    let keyRect = CGRect(x: 252 * s, y: 270 * s, width: 520 * s, height: 394 * s)
    let keyPath = drawRoundedRect(keyRect, radius: 158 * s)
    let keyGradient = NSGradient(colors: [
        NSColor(hex: 0xF9FBFF),
        NSColor(hex: 0xE8F0FB),
        NSColor(hex: 0xCFDDEE)
    ])!
    keyGradient.draw(in: keyPath, angle: -90)

    let topPlate = drawRoundedRect(keyRect.insetBy(dx: 18 * s, dy: 18 * s), radius: 138 * s)
    NSColor.white.withAlphaComponent(0.16).setStroke()
    topPlate.lineWidth = 6 * s
    topPlate.stroke()

    let highlightRect = CGRect(x: keyRect.minX + 24 * s, y: keyRect.midY + 42 * s, width: keyRect.width - 48 * s, height: 118 * s)
    let highlightPath = drawRoundedRect(highlightRect, radius: 70 * s)
    NSColor.white.withAlphaComponent(0.32).setFill()
    highlightPath.fill()

    keyPath.lineWidth = 9 * s
    NSColor(hex: 0xFFFFFF, alpha: 0.55).setStroke()
    keyPath.stroke()

    let symbolStyle = NSMutableParagraphStyle()
    symbolStyle.alignment = .center

    let symbolFont = NSFont.systemFont(ofSize: 254 * s, weight: .black)
    let symbolAttributes: [NSAttributedString.Key: Any] = [
        .font: symbolFont,
        .foregroundColor: NSColor(hex: 0x10243A, alpha: 0.95),
        .paragraphStyle: symbolStyle
    ]
    let symbol = NSAttributedString(string: "⌘", attributes: symbolAttributes)
    let symbolRect = CGRect(x: keyRect.minX, y: keyRect.minY + 62 * s, width: keyRect.width, height: 250 * s)
    symbol.draw(in: symbolRect)

    let sparkleCenter = CGPoint(x: 740 * s, y: 712 * s)
    let sparkleHalo = NSBezierPath(ovalIn: CGRect(x: sparkleCenter.x - 88 * s, y: sparkleCenter.y - 88 * s, width: 176 * s, height: 176 * s))
    NSColor(hex: 0x67E8F9, alpha: 0.14).setFill()
    sparkleHalo.fill()

    let sparklePath = drawSparkle(center: sparkleCenter, outerRadius: 72 * s, innerRadius: 24 * s)
    let sparkleGradient = NSGradient(colors: [
        NSColor(hex: 0xFFF2B8),
        NSColor(hex: 0xFFD166),
        NSColor(hex: 0xF59E0B)
    ])!
    sparkleGradient.draw(in: sparklePath, angle: -90)

    sparklePath.lineWidth = 6 * s
    NSColor.white.withAlphaComponent(0.42).setStroke()
    sparklePath.stroke()

    let smallSpark = drawSparkle(center: CGPoint(x: 828 * s, y: 786 * s), outerRadius: 22 * s, innerRadius: 8 * s)
    NSColor.white.withAlphaComponent(0.92).setFill()
    smallSpark.fill()
}

func renderLogo(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    drawLogo(in: NSRect(x: 0, y: 0, width: size, height: size))
    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "KeyTipLogo", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode PNG"])
    }

    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let brandingDir = root.appendingPathComponent("Branding", isDirectory: true)
let appIconDir = root.appendingPathComponent("KeyTip/Assets.xcassets/AppIcon.appiconset", isDirectory: true)

let outputs: [(filename: String, size: CGFloat)] = [
    ("appicon_16.png", 16),
    ("appicon_16@2x.png", 32),
    ("appicon_32.png", 32),
    ("appicon_32@2x.png", 64),
    ("appicon_128.png", 128),
    ("appicon_128@2x.png", 256),
    ("appicon_256.png", 256),
    ("appicon_256@2x.png", 512),
    ("appicon_512.png", 512),
    ("appicon_512@2x.png", 1024)
]

try FileManager.default.createDirectory(at: brandingDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: appIconDir, withIntermediateDirectories: true)

let hero = renderLogo(size: 1024)
try writePNG(hero, to: brandingDir.appendingPathComponent("keytip-logo-1024.png"))

for output in outputs {
    let image = renderLogo(size: output.size)
    try writePNG(image, to: appIconDir.appendingPathComponent(output.filename))
}

print(brandingDir.appendingPathComponent("keytip-logo-1024.png").path)
