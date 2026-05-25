#!/usr/bin/env swift
import AppKit
import Foundation

// Use CGContext directly to avoid Retina display scale doubling the pixel count.
func makeIcon(pixelSize: Int) -> CGImage {
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    // Scale from 32×32 viewBox → pixelSize, flip Y (CG origin is bottom-left; SVG is top-left)
    let scale = CGFloat(pixelSize) / 32.0
    ctx.scaleBy(x: scale, y: scale)
    ctx.translateBy(x: 0, y: 32)
    ctx.scaleBy(x: 1, y: -1)

    // Black template — system renders as appropriate menu bar color
    ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
    ctx.setFillColor(CGColor(gray: 0, alpha: 1))

    // Back page (history indicator) — 35% opacity, thin stroke
    // SVG: x=10, y=8, w=14, h=17
    ctx.setAlpha(0.35)
    let backPath = CGPath(roundedRect: CGRect(x: 10, y: 8, width: 14, height: 17), cornerWidth: 2, cornerHeight: 2, transform: nil)
    ctx.addPath(backPath)
    ctx.setLineWidth(1.5)
    ctx.strokePath()
    ctx.setAlpha(1.0)

    // Main clipboard body: SVG x=7, y=5, w=16, h=21
    ctx.setLineWidth(2.0)
    let bodyPath = CGPath(roundedRect: CGRect(x: 7, y: 5, width: 16, height: 21), cornerWidth: 2.5, cornerHeight: 2.5, transform: nil)
    ctx.addPath(bodyPath)
    ctx.strokePath()

    // Clip bar at top: SVG x=11, y=3, w=7, h=4
    let barPath = CGPath(roundedRect: CGRect(x: 11, y: 3, width: 7, height: 4), cornerWidth: 1.5, cornerHeight: 1.5, transform: nil)
    ctx.addPath(barPath)
    ctx.fillPath()

    // Content lines
    for (x, y, w) in [(10.0, 12.0, 10.0), (10.0, 15.5, 7.0), (10.0, 19.0, 5.0)] {
        let p = CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: 1.5), cornerWidth: 0.75, cornerHeight: 0.75, transform: nil)
        ctx.addPath(p)
        ctx.fillPath()
    }

    return ctx.makeImage()!
}

func savePNG(_ image: CGImage, to path: String) throws {
    guard let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil) else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        throw CocoaError(.fileWriteUnknown)
    }
}

let outDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath

// 18pt @1x = 18px, 18pt @2x = 36px
try savePNG(makeIcon(pixelSize: 18), to: "\(outDir)/icon.png")
try savePNG(makeIcon(pixelSize: 36), to: "\(outDir)/icon@2x.png")
print("Icons written to \(outDir)/icon.png (18px) and icon@2x.png (36px)")
