// scripts/render-icon.swift — renders the two image layers of App/AppIcon.icon, the Icon Composer document of the
// app icon "Past white" (DESIGN.md §14). Original artwork, MIT. Ported from Cranny's renderer (makeContext, write,
// radial and rgb, the 824-pt body grid); the artwork is new. WP0a drew a first version of the concept; WP14 refined
// it (a small hot bloom, a screen below white, a perspective lean instead of an in-plane tilt, a keyline that shows at
// 128 px); WP17 compares it with the incumbent's icon before release.
//
//   make icon                                          # = xcrun swift scripts/render-icon.swift App/AppIcon.icon/Assets
//
// Writes screen.png (a rounded screen at P3 0.90 → 0.84 top to bottom, leaning back in a slight perspective, with a
// warm keyline just inside the edge the bloom crosses) and bloom.png (a white-hot core on the screen's upper trailing corner, past its frame, that
// falls off through a warm white to nothing; blended plus-lighter by icon.json, so it reads brighter than the screen
// and lights the dark around it without a grey haze). Both are 1024 × 1024 with transparency. The graphite fill, the
// glass, the shadow and the system's macOS 14/15 fallback come from icon.json and actool.
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

/// A Display P3 grey (DESIGN.md §14 gives the screen as P3 0.90 → 0.84, below the bloom's white).
func p3Grey(_ value: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB(),
            components: [value, value, value, alpha]) ?? rgb(0xDBDBDB, alpha)
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

/// A radial gradient around `center`.
func radial(_ ctx: CGContext, center: CGPoint, radius: CGFloat, colors: [CGColor], locations: [CGFloat]) {
    guard let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray,
                                    locations: locations) else { fail("bad gradient") }
    ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
}

func point(_ a: CGPoint, towards b: CGPoint, by distance: CGFloat) -> CGPoint {
    let length = hypot(b.x - a.x, b.y - a.y)
    return CGPoint(x: a.x + (b.x - a.x) / length * distance, y: a.y + (b.y - a.y) / length * distance)
}

// The screen: 0.66 × 0.44 of the body, centred slightly below the middle, leaning back: its top edge is 5 % narrower
// than its bottom edge (inset 2.5 % of the width at each end) and the sides converge towards it (a perspective, not a rotation in the image plane, so the
// screen never looks crooked). Corner radius 0.05 of the body.
let width = 0.66 * body, height = 0.44 * body
let center = CGPoint(x: 512, y: 548)
let topInset = 0.025 * width
let bottomLeft = CGPoint(x: center.x - width / 2, y: center.y + height / 2)
let bottomRight = CGPoint(x: center.x + width / 2, y: center.y + height / 2)
let topRight = CGPoint(x: center.x + width / 2 - topInset, y: center.y - height / 2)
let topLeft = CGPoint(x: center.x - width / 2 + topInset, y: center.y - height / 2)
let cornerRadius = 0.05 * body
let screenPath: CGPath = {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: (bottomLeft.x + bottomRight.x) / 2, y: bottomLeft.y))
    for (corner, next) in [(bottomRight, topRight), (topRight, topLeft), (topLeft, bottomLeft), (bottomLeft, bottomRight)] {
        path.addArc(tangent1End: corner, tangent2End: next, radius: cornerRadius)
    }
    path.closeSubpath()
    return path
}()
/// Where the bloom sits: on the screen's upper trailing corner, just past the frame, so its white-hot core straddles
/// the edge and the light visibly leaves the screen.
let bloomCenter = topRight

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

// 1. Screen: P3 0.90 at the top → 0.84 at the bottom, so the bloom's white reads brighter than the screen ("past
//    white"), with a 9-pt keyline in the dark-mode warm accent (#FFB020) along the stretch of the edge that the bloom
//    crosses: wide enough to show at 128 px, the mark's signature. The keyline lies inside the edge: it is stroked at
//    twice its width on the edge and clipped to the screen, so the screen's silhouette stays the rounded screen (a
//    stroke centred on the edge would stand half outside it and step up where it starts, like a folder tab).
let screen = makeContext()
screen.saveGState()
screen.addPath(screenPath)
screen.clip()
guard let shade = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.displayP3), colors: [p3Grey(0.90), p3Grey(0.84)] as CFArray,
                             locations: [0, 1]) else { fail("bad gradient") }
screen.drawLinearGradient(shade, start: CGPoint(x: center.x, y: topLeft.y), end: CGPoint(x: center.x, y: bottomLeft.y), options: [])
let keyline = CGMutablePath()
keyline.move(to: point(topRight, towards: topLeft, by: 0.24 * body))
keyline.addArc(tangent1End: topRight, tangent2End: bottomRight, radius: cornerRadius)
keyline.addLine(to: point(topRight, towards: bottomRight, by: 0.17 * body))
screen.addPath(keyline)
screen.setStrokeColor(rgb(0xFFB020))
screen.setLineWidth(2 * 9 * 1024 / body)
screen.setLineCap(.round)
screen.setLineJoin(.round)
screen.strokePath()
screen.restoreGState()
write(screen, "screen.png")

// 2. Bloom, over a radius of 0.34 of the body: a solid white core to 0.10 of the radius (0.034 of the body), then a
//    warm white at 80 % (0.22 of the radius), 30 % (0.40) and 7 % (0.62, about 0.21 of the body), and nothing by 0.8
//    of the radius (0.27 of the body). It thins out fast instead of holding a wide half-transparent haze: plus-lighter
//    over the graphite turns a wide one into a muddy grey-brown.
let bloom = makeContext()
radial(bloom, center: bloomCenter, radius: 0.34 * body,
       colors: [rgb(0xFFFFFF), rgb(0xFFFFFF), rgb(0xFFF6E8, 0.8), rgb(0xFFEBD0, 0.3), rgb(0xFFE7C2, 0.07),
                rgb(0xFFE7C2, 0)],
       locations: [0, 0.10, 0.22, 0.40, 0.62, 0.8])
write(bloom, "bloom.png")
