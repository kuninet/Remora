#!/usr/bin/env swift
import AppKit
import Foundation

let _ = NSApplication.shared

let outputDir: String
if CommandLine.arguments.count > 1 {
    outputDir = CommandLine.arguments[1]
} else {
    outputDir = FileManager.default.currentDirectoryPath + "/Resources"
}

try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

// Draw the remora silhouette as a template image (black on transparent)
// size: points, returns NSImage ready to be saved as PNG
func drawMenuBarIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    ctx.setShouldAntialias(true)
    let f = size / 22.0  // scale relative to 22pt reference size
    let black = CGColor(gray: 0.0, alpha: 1.0)
    let white = CGColor(gray: 1.0, alpha: 1.0)

    // -- Body (spindle, facing left) --
    // y=0 bottom, y=size top
    // Body center at (11f, 9f), length ~16f, half-height ~4f
    let headX = 4.5 * f
    let tailX = 19.5 * f
    let bodyY = 9.0 * f
    let bodyHH = 3.8 * f
    let bulgeX = headX + (tailX - headX) * 0.38

    ctx.setFillColor(black)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: headX, y: bodyY))
    ctx.addCurve(
        to: CGPoint(x: tailX, y: bodyY + 2.5 * f),
        control1: CGPoint(x: bulgeX, y: bodyY + bodyHH),
        control2: CGPoint(x: tailX - 5 * f, y: bodyY + 3.8 * f)
    )
    ctx.addLine(to: CGPoint(x: tailX, y: bodyY - 2.5 * f))
    ctx.addCurve(
        to: CGPoint(x: headX, y: bodyY),
        control1: CGPoint(x: tailX - 5 * f, y: bodyY - 3.8 * f),
        control2: CGPoint(x: bulgeX, y: bodyY - bodyHH)
    )
    ctx.closePath()
    ctx.fillPath()

    // -- Tail fins (forked) --
    ctx.setFillColor(black)
    // Upper lobe
    ctx.beginPath()
    ctx.move(to: CGPoint(x: tailX, y: bodyY + 2.5 * f))
    ctx.addLine(to: CGPoint(x: tailX + 3.5 * f, y: bodyY + 7 * f))
    ctx.addLine(to: CGPoint(x: tailX + 1.5 * f, y: bodyY + 1.5 * f))
    ctx.closePath()
    ctx.fillPath()
    // Lower lobe
    ctx.beginPath()
    ctx.move(to: CGPoint(x: tailX, y: bodyY - 2.5 * f))
    ctx.addLine(to: CGPoint(x: tailX + 3.5 * f, y: bodyY - 7 * f))
    ctx.addLine(to: CGPoint(x: tailX + 1.5 * f, y: bodyY - 1.5 * f))
    ctx.closePath()
    ctx.fillPath()

    // -- Suction disc (above head, vertical oval) --
    // The disc is the key identifying feature of the remora
    let discCX = 6.2 * f
    let discCY = 14.5 * f
    let discRX = 2.5 * f
    let discRY = 5.5 * f

    ctx.setFillColor(black)
    ctx.beginPath()
    ctx.addEllipse(in: CGRect(
        x: discCX - discRX, y: discCY - discRY,
        width: discRX * 2, height: discRY * 2
    ))
    ctx.fillPath()

    // Disc stripes (white lines = suction ridges, visible as light cutout)
    ctx.setStrokeColor(white)
    ctx.setLineWidth(max(0.5, 0.9 * f))
    ctx.setLineCap(.round)
    let stripeCount = 4
    for i in 0..<stripeCount {
        let t = CGFloat(i) / CGFloat(stripeCount - 1)
        let y = discCY - (discRY - 1.2 * f) + t * (discRY - 1.2 * f) * 2
        let dy = (y - discCY) / discRY
        guard abs(dy) <= 1.0 else { continue }
        let hw = discRX * sqrt(1.0 - dy * dy) - 0.8 * f
        if hw > 0.5 * f {
            ctx.beginPath()
            ctx.move(to: CGPoint(x: discCX - hw, y: y))
            ctx.addLine(to: CGPoint(x: discCX + hw, y: y))
            ctx.strokePath()
        }
    }

    image.unlockFocus()
    return image
}

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

let targets: [(String, CGFloat)] = [
    ("MenuBarIcon.png", 16),
    ("MenuBarIcon@2x.png", 32),
]

for (filename, size) in targets {
    let img = drawMenuBarIcon(size: size)
    let path = "\(outputDir)/\(filename)"
    do {
        try savePNG(img, to: path)
        print("Generated \(filename) (\(Int(size))×\(Int(size)))")
    } catch {
        fputs("Error: \(error)\n", stderr)
        exit(1)
    }
}

print("\nMenuBar icons ready in: \(outputDir)")
