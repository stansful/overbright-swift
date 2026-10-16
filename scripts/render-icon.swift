// scripts/render-icon.swift — renders the two image layers of App/AppIcon.icon, the Icon Composer document of the
// app icon "Past white" (DESIGN.md §14). Original artwork, MIT. Ported from Cranny's renderer (makeContext, write,
// radial and rgb, the 824-pt body grid); the artwork is new. WP0a draws a first version of the concept; WP17 refines it
// (and compares it with the incumbent's icon before release).
//
//   make icon                                          # = xcrun swift scripts/render-icon.swift App/AppIcon.icon/Assets
//
// Writes screen.png (a rounded white screen, tilted slightly up, with a warm keyline where the bloom crosses its
// edge) and bloom.png (the light spilling past the screen's upper trailing corner, blended plus-lighter by
// icon.json). Both are 1024 × 1024 with transparency. The graphite fill, the glass, the shadow and the system's
// macOS 14/15 fallback come from icon.json and actool.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "App/AppIcon.icon/Assets", isDirectory: true)
let side = 1024
/// DESIGN.md §14 sizes the artwork relative to the 824-pt body of the macOS icon grid.
let body: CGFloat = 824

/// Stops the build tool with a message (never used in app code, which has no fatalError).
func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("render-icon: \(message)\n".utf8))
    exit(1)
}

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// A Display P3 grey (DESIGN.md §14 gives the screen white as P3 0.96).
func p3Grey(_ value: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB(),
            components: [value, value, value, alpha]) ?? rgb(0xF5F5F5, alpha)
}

/// A transparent sRGB canvas with a top-left origin (y grows downward, like SwiftUI).
func makeContext() -> CGContext {
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fail("cannot create a bitmap context")
    }
    ctx.translateBy(x: 0, y: CGFloat(side))
    ctx.scaleBy(x: 1, y: -1)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high
    return ctx
}

func write(_ ctx: CGContext, _ name: String) {
    let url = outputDirectory.appending(path: name)
    guard let image = ctx.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fail("cannot write \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fail("cannot write \(url.path)") }
    print("wrote \(url.path)")
}

/// A radial gradient squashed vertically by `squash` (1.25 = 25 % flatter than a circle).
func radial(_ ctx: CGContext, center: CGPoint, radius: CGFloat, squash: CGFloat, colors: [CGColor], locations: [CGFloat]) {
    guard let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray,
                                    locations: locations) else { fail("bad gradient") }
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.scaleBy(x: 1, y: 1 / squash)
    ctx.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: radius, options: [])
    ctx.restoreGState()
}

// The screen: 0.62 × 0.44 of the body, corner radius 0.05, centred slightly below the middle, tilted 4° up.
let screenSize = CGSize(width: 0.62 * body, height: 0.44 * body)
let screenCenter = CGPoint(x: 512, y: 540)
let tilt: CGFloat = -4 * .pi / 180
let screenRect = CGRect(x: -screenSize.width / 2, y: -screenSize.height / 2, width: screenSize.width, height: screenSize.height)
let screenPath = CGPath(roundedRect: screenRect, cornerWidth: 0.05 * body, cornerHeight: 0.05 * body, transform: nil)
/// The screen's upper trailing corner in canvas coordinates: where the bloom spills over the frame.
let corner: CGPoint = {
    let local = CGPoint(x: screenRect.maxX - 0.03 * body, y: screenRect.minY + 0.03 * body)
    return CGPoint(x: screenCenter.x + local.x * cos(tilt) - local.y * sin(tilt),
                   y: screenCenter.y + local.x * sin(tilt) + local.y * cos(tilt))
}()

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

// 1. Screen: white (P3 0.96) with a 3-pt keyline in the dark-mode warm accent (#FFB020) along the stretch of the
//    edge that the bloom crosses.
let screen = makeContext()
screen.saveGState()
screen.translateBy(x: screenCenter.x, y: screenCenter.y)
screen.rotate(by: tilt)
screen.addPath(screenPath)
screen.setFillColor(p3Grey(0.96))
screen.fillPath()
let keyline = CGMutablePath()
keyline.move(to: CGPoint(x: screenRect.maxX - 0.22 * body, y: screenRect.minY))
keyline.addLine(to: CGPoint(x: screenRect.maxX - 0.05 * body, y: screenRect.minY))
keyline.addArc(tangent1End: CGPoint(x: screenRect.maxX, y: screenRect.minY),
               tangent2End: CGPoint(x: screenRect.maxX, y: screenRect.minY + 0.05 * body), radius: 0.05 * body)
keyline.addLine(to: CGPoint(x: screenRect.maxX, y: screenRect.minY + 0.16 * body))
screen.addPath(keyline)
screen.setStrokeColor(rgb(0xFFB020))
screen.setLineWidth(3 * 1024 / body)
screen.setLineCap(.round)
screen.strokePath()
screen.restoreGState()
write(screen, "screen.png")

// 2. Bloom: a white core at the corner, fading through a pale warm tint (#FFE7C2 at 40 %) to transparent, reaching
//    past the screen's frame into the dark.
let bloom = makeContext()
radial(bloom, center: corner, radius: 0.40 * body, squash: 1.0,
       colors: [rgb(0xFFFFFF), rgb(0xFFFFFF, 0.85), rgb(0xFFE7C2, 0.40), rgb(0xFFE7C2, 0)],
       locations: [0, 0.18, 0.55, 1])
write(bloom, "bloom.png")
