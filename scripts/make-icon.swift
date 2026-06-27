#!/usr/bin/env swift
import AppKit
import Foundation

// Ensure AppKit is ready for off-screen drawing
let _ = NSApplication.shared

let outputDir: String
if CommandLine.arguments.count > 1 {
    outputDir = CommandLine.arguments[1]
} else {
    let cwd = FileManager.default.currentDirectoryPath
    outputDir = "\(cwd)/build/AppIcon.iconset"
}

do {
    try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
} catch {
    fputs("Error: ディレクトリの作成に失敗しました: \(error.localizedDescription)\n", stderr)
    exit(1)
}

let iconsetSizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

// MARK: - Drawing

func drawIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let f = s / 1024.0  // scale factor

    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    ctx.setShouldAntialias(true)
    ctx.setAllowsAntialiasing(true)

    // -- Background gradient (bottom=teal, top=light cyan) --
    let topR: CGFloat = 0.910; let topG: CGFloat = 0.957; let topB: CGFloat = 0.973
    let botR: CGFloat = 0.722; let botG: CGFloat = 0.863; let botB: CGFloat = 0.902

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradColors = [
        CGColor(colorSpace: colorSpace, components: [botR, botG, botB, 1.0])!,
        CGColor(colorSpace: colorSpace, components: [topR, topG, topB, 1.0])!,
    ]
    let locs: [CGFloat] = [0.0, 1.0]
    if let grad = CGGradient(colorsSpace: colorSpace, colors: gradColors as CFArray, locations: locs) {
        ctx.drawLinearGradient(grad,
            start: CGPoint(x: s / 2, y: 0),
            end: CGPoint(x: s / 2, y: s),
            options: [])
    }

    // -- Colors --
    let tealColor = CGColor(colorSpace: colorSpace, components: [0.122, 0.353, 0.431, 1.0])!
    let tealFaded = CGColor(colorSpace: colorSpace, components: [0.122, 0.353, 0.431, 0.82])!
    let white = CGColor(colorSpace: colorSpace, components: [1.0, 1.0, 1.0, 1.0])!
    let whiteStripe = CGColor(colorSpace: colorSpace, components: [1.0, 1.0, 1.0, 0.5])!
    let whiteBelly = CGColor(colorSpace: colorSpace, components: [1.0, 1.0, 1.0, 0.13])!
    let black = CGColor(colorSpace: colorSpace, components: [0.0, 0.0, 0.0, 1.0])!

    // Fish geometry (all in 1024-relative coords, scaled by f)
    let headX = 175.0 * f
    let tailX = 790.0 * f
    let bodyY = 460.0 * f
    let bodyHH = 105.0 * f  // half-height at widest
    let bulgeX = headX + (tailX - headX) * 0.33

    // -- Body shape (spindle/fusiform) --
    ctx.setFillColor(tealColor)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: headX, y: bodyY))
    ctx.addCurve(
        to: CGPoint(x: tailX, y: bodyY + 32 * f),
        control1: CGPoint(x: bulgeX, y: bodyY + bodyHH),
        control2: CGPoint(x: tailX - 130 * f, y: bodyY + 58 * f)
    )
    ctx.addLine(to: CGPoint(x: tailX, y: bodyY - 32 * f))
    ctx.addCurve(
        to: CGPoint(x: headX, y: bodyY),
        control1: CGPoint(x: tailX - 130 * f, y: bodyY - 58 * f),
        control2: CGPoint(x: bulgeX, y: bodyY - bodyHH)
    )
    ctx.closePath()
    ctx.fillPath()

    // -- Belly highlight --
    ctx.setStrokeColor(whiteBelly)
    ctx.setLineWidth(20 * f)
    ctx.setLineCap(.round)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: headX + 40 * f, y: bodyY - 22 * f))
    ctx.addCurve(
        to: CGPoint(x: tailX - 110 * f, y: bodyY - 28 * f),
        control1: CGPoint(x: bulgeX - 30 * f, y: bodyY - 65 * f),
        control2: CGPoint(x: tailX - 200 * f, y: bodyY - 35 * f)
    )
    ctx.strokePath()

    // -- Dorsal fin --
    ctx.setFillColor(tealFaded)
    let dorStartX = headX + (tailX - headX) * 0.22
    let dorEndX = headX + (tailX - headX) * 0.62
    ctx.beginPath()
    ctx.move(to: CGPoint(x: dorStartX, y: bodyY + 82 * f))
    ctx.addCurve(
        to: CGPoint(x: dorEndX, y: bodyY + 58 * f),
        control1: CGPoint(x: dorStartX + 30 * f, y: bodyY + 165 * f),
        control2: CGPoint(x: dorEndX - 50 * f, y: bodyY + 138 * f)
    )
    ctx.addLine(to: CGPoint(x: dorStartX + 15 * f, y: bodyY + 88 * f))
    ctx.closePath()
    ctx.fillPath()

    // -- Pectoral fin --
    ctx.setFillColor(tealFaded)
    let pFinCX = headX + (tailX - headX) * 0.28
    ctx.beginPath()
    ctx.move(to: CGPoint(x: pFinCX, y: bodyY - 38 * f))
    ctx.addLine(to: CGPoint(x: pFinCX - 55 * f, y: bodyY - 150 * f))
    ctx.addLine(to: CGPoint(x: pFinCX + 90 * f, y: bodyY - 48 * f))
    ctx.closePath()
    ctx.fillPath()

    // -- Tail fins (forked) --
    ctx.setFillColor(tealColor)
    // Upper lobe
    ctx.beginPath()
    ctx.move(to: CGPoint(x: tailX, y: bodyY + 32 * f))
    ctx.addLine(to: CGPoint(x: tailX + 115 * f, y: bodyY + 148 * f))
    ctx.addLine(to: CGPoint(x: tailX + 50 * f, y: bodyY + 22 * f))
    ctx.closePath()
    ctx.fillPath()
    // Lower lobe
    ctx.beginPath()
    ctx.move(to: CGPoint(x: tailX, y: bodyY - 32 * f))
    ctx.addLine(to: CGPoint(x: tailX + 115 * f, y: bodyY - 148 * f))
    ctx.addLine(to: CGPoint(x: tailX + 50 * f, y: bodyY - 22 * f))
    ctx.closePath()
    ctx.fillPath()

    // -- Suction disc (remora's distinctive feature) --
    // Oval on top of head, facing up
    let suckCX = 218.0 * f
    let suckCY = 600.0 * f
    let suckRX = 62.0 * f
    let suckRY = 132.0 * f

    // Disc body
    ctx.setFillColor(tealColor)
    ctx.beginPath()
    ctx.addEllipse(in: CGRect(x: suckCX - suckRX, y: suckCY - suckRY, width: suckRX * 2, height: suckRY * 2))
    ctx.fillPath()

    // Disc stripes (suction ridges)
    let stripeCount = 8
    let stripeMargin = 10.0 * f
    let innerRY = suckRY - stripeMargin
    let innerRX = suckRX - stripeMargin * 0.5

    ctx.setStrokeColor(whiteStripe)
    ctx.setLineWidth(max(1.0, 2.8 * f))
    ctx.setLineCap(.round)

    for i in 0..<stripeCount {
        let t = CGFloat(i) / CGFloat(stripeCount - 1)
        let y = suckCY - innerRY + t * innerRY * 2
        let dy = (y - suckCY) / innerRY
        guard abs(dy) <= 1.0 else { continue }
        let hw = innerRX * sqrt(1.0 - dy * dy)
        if hw > 3 * f {
            ctx.beginPath()
            ctx.move(to: CGPoint(x: suckCX - hw + 2 * f, y: y))
            ctx.addLine(to: CGPoint(x: suckCX + hw - 2 * f, y: y))
            ctx.strokePath()
        }
    }

    // Disc outline
    ctx.setStrokeColor(CGColor(colorSpace: colorSpace, components: [1.0, 1.0, 1.0, 0.25])!)
    ctx.setLineWidth(max(1.0, 2.0 * f))
    ctx.beginPath()
    ctx.addEllipse(in: CGRect(x: suckCX - suckRX, y: suckCY - suckRY, width: suckRX * 2, height: suckRY * 2))
    ctx.strokePath()

    // -- Eye --
    let eyeX = 235.0 * f
    let eyeY = 472.0 * f
    let eyeR = 20.0 * f

    ctx.setFillColor(white)
    ctx.beginPath()
    ctx.addEllipse(in: CGRect(x: eyeX - eyeR, y: eyeY - eyeR, width: eyeR * 2, height: eyeR * 2))
    ctx.fillPath()

    let pupilR = 11.0 * f
    ctx.setFillColor(black)
    ctx.beginPath()
    ctx.addEllipse(in: CGRect(x: eyeX - pupilR - 2 * f, y: eyeY - pupilR, width: pupilR * 2, height: pupilR * 2))
    ctx.fillPath()

    // Eye highlight
    let hiliteR = 4.0 * f
    ctx.setFillColor(white)
    ctx.beginPath()
    ctx.addEllipse(in: CGRect(x: eyeX + 1 * f, y: eyeY + 3 * f, width: hiliteR * 2, height: hiliteR * 2))
    ctx.fillPath()

    image.unlockFocus()
    return image
}

// MARK: - Save PNG

func savePNG(_ image: NSImage, to path: String) throws {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw NSError(domain: "IconGen", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage"])
    }
    let bmp = NSBitmapImageRep(cgImage: cgImage)
    bmp.size = image.size
    guard let data = bmp.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGen", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG"])
    }
    try data.write(to: URL(fileURLWithPath: path))
}

// MARK: - Main

for (filename, size) in iconsetSizes {
    let img = drawIcon(size: size)
    let path = "\(outputDir)/\(filename)"
    do {
        try savePNG(img, to: path)
        print("Generated \(filename) (\(size)×\(size))")
    } catch {
        fputs("Error: \(error)\n", stderr)
        exit(1)
    }
}

print("\nIconset ready at: \(outputDir)")
print("Run: iconutil -c icns \"\(outputDir)\" -o Resources/AppIcon.icns")
