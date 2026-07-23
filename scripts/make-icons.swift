// Generates the app icon and the menu bar template image from the same geometric
// character the app draws in code. Run: swift scripts/make-icons.swift <Assets.xcassets path>
// Force-unwraps are fine here: this is a build tool, not shipping code.

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let background = CGColor(red: 0.30, green: 0.36, blue: 0.50, alpha: 1)
let bodyColor = CGColor(red: 0.94, green: 0.95, blue: 0.97, alpha: 1)
let eyeColor = CGColor(red: 0.20, green: 0.24, blue: 0.32, alpha: 1)
let accent = CGColor(red: 0.92, green: 0.68, blue: 0.36, alpha: 1)
let black = CGColor(red: 0, green: 0, blue: 0, alpha: 1)

func makeContext(_ size: Int) -> CGContext {
    let ctx = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high
    return ctx
}

func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func addEyes(_ ctx: CGContext, body: CGRect) {
    let eyeR = body.width * 0.085
    let spacing = body.width * 0.28
    let cy = body.midY + body.height * 0.07
    for dx in [-spacing / 2, spacing / 2] {
        let r = CGRect(x: body.midX + dx - eyeR, y: cy - eyeR, width: eyeR * 2, height: eyeR * 2)
        ctx.addPath(CGPath(ellipseIn: r, transform: nil))
    }
}

func drawIcon(size: Int, template: Bool) -> CGImage {
    let s = CGFloat(size)
    let ctx = makeContext(size)

    if !template {
        let margin = s * 0.095
        let bg = CGRect(x: margin, y: margin, width: s - 2 * margin, height: s - 2 * margin)
        ctx.addPath(rounded(bg, bg.width * 0.224))
        ctx.setFillColor(background)
        ctx.fillPath()
    }

    let bodyW = s * (template ? 0.60 : 0.44)
    let bodyRect = CGRect(x: (s - bodyW) / 2, y: (s - bodyW) / 2 - s * 0.03, width: bodyW, height: bodyW)

    let stalkW = bodyW * 0.06
    let stalkRect = CGRect(x: s / 2 - stalkW / 2, y: bodyRect.maxY - stalkW * 0.2, width: stalkW, height: bodyW * 0.18)
    let tipR = bodyW * 0.075
    let tipRect = CGRect(x: s / 2 - tipR, y: stalkRect.maxY - tipR * 0.3, width: tipR * 2, height: tipR * 2)

    if template {
        ctx.setFillColor(black)
        ctx.addPath(rounded(bodyRect, bodyW * 0.3))
        ctx.addPath(rounded(stalkRect, stalkW / 2))
        ctx.addPath(CGPath(ellipseIn: tipRect, transform: nil))
        ctx.fillPath()
        ctx.setBlendMode(.clear)
        addEyes(ctx, body: bodyRect)
        ctx.fillPath()
        ctx.setBlendMode(.normal)
    } else {
        ctx.setFillColor(bodyColor)
        ctx.addPath(rounded(stalkRect, stalkW / 2))
        ctx.fillPath()
        ctx.setFillColor(accent)
        ctx.addPath(CGPath(ellipseIn: tipRect, transform: nil))
        ctx.fillPath()
        ctx.setFillColor(bodyColor)
        ctx.addPath(rounded(bodyRect, bodyW * 0.3))
        ctx.fillPath()
        ctx.setFillColor(eyeColor)
        addEyes(ctx, body: bodyRect)
        ctx.fillPath()
    }

    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let appIconDir = root.appendingPathComponent("AppIcon.appiconset")
let menuDir = root.appendingPathComponent("MenuBarIcon.imageset")
try? FileManager.default.createDirectory(at: appIconDir, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(at: menuDir, withIntermediateDirectories: true)

for px in [16, 32, 64, 128, 256, 512, 1024] {
    writePNG(drawIcon(size: px, template: false), to: appIconDir.appendingPathComponent("icon_\(px).png"))
}
for px in [18, 36] {
    writePNG(drawIcon(size: px, template: true), to: menuDir.appendingPathComponent("menubar_\(px).png"))
}
print("icons written to \(root.path)")
