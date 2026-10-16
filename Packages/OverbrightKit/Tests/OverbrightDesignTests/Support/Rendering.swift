// OverbrightDesignTests/Support/Rendering.swift — renders a view off screen (ImageRenderer, 2×, over a background) and
// reads its pixels, so tests can check where colours land: the warm fill, the marker, mirroring. Nothing is shown on
// screen and no window is ordered in. Ported from Cranny's RenderedPixels (the owner's MIT code).
import AppKit
import SwiftUI
import Testing
@testable import OverbrightDesign

/// An RGBA copy of a rendered image; coordinates in points (2×), y down.
struct RenderedPixels {
    /// One pixel, components 0…1.
    struct Pixel {
        let r, g, b, a: Double
        /// Close to `color` (each channel within `tolerance`).
        func isClose(to color: SRGBA, tolerance: Double = 0.06) -> Bool {
            abs(r - color.red) <= tolerance && abs(g - color.green) <= tolerance && abs(b - color.blue) <= tolerance
        }
    }

    let width: Int, height: Int
    private let bytes: [UInt8]

    init?(_ image: CGImage) {
        width = image.width; height = image.height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let ctx = CGContext(data: raw.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                                      bytesPerRow: image.width * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard drawn else { return nil }
        bytes = buffer
    }

    /// The pixel at (x, y) in pixels.
    func pixel(x: Int, y: Int) -> Pixel {
        let i = (y * width + x) * 4
        return Pixel(r: Double(bytes[i]) / 255, g: Double(bytes[i + 1]) / 255, b: Double(bytes[i + 2]) / 255,
                     a: Double(bytes[i + 3]) / 255)
    }

    /// The centre of the pixels that match, in points; nil when none does.
    func centroid(of matches: (Pixel) -> Bool) -> CGPoint? {
        var sx = 0.0, sy = 0.0, n = 0.0
        for y in 0..<height { for x in 0..<width where matches(pixel(x: x, y: y)) { sx += Double(x); sy += Double(y); n += 1 } }
        guard n > 0 else { return nil }
        return CGPoint(x: (sx / n + 0.5) / 2, y: (sy / n + 0.5) / 2)
    }

    /// How many pixels match.
    func count(of matches: (Pixel) -> Bool) -> Int {
        var n = 0
        for y in 0..<height { for x in 0..<width where matches(pixel(x: x, y: y)) { n += 1 } }
        return n
    }

    /// The x range (in points) of the pixels that match, nil when none does.
    func xRange(of matches: (Pixel) -> Bool) -> ClosedRange<CGFloat>? {
        var low = Int.max, high = Int.min
        for y in 0..<height { for x in 0..<width where matches(pixel(x: x, y: y)) { low = min(low, x); high = max(high, x) } }
        guard low <= high else { return nil }
        return CGFloat(low) / 2...CGFloat(high + 1) / 2
    }
}

/// Renders `view` at `size` over `background` with `theme` as the surface root, in `scheme` and `direction`.
@MainActor func render(_ view: some View, size: CGSize, theme: OverbrightTheme = OverbrightTheme(),
                       scheme: ColorScheme = .light, direction: LayoutDirection = .leftToRight,
                       background: Color = .white) throws -> RenderedPixels {
    let content = view
        .frame(width: size.width, height: size.height)
        .background(background)
        .overbrightThemeRoot(theme)
        .environment(\.layoutDirection, direction)
        .environment(\.colorScheme, scheme)
    let renderer = ImageRenderer(content: content)
    renderer.scale = 2
    let image = try #require(renderer.cgImage)
    return try #require(RenderedPixels(image))
}

/// English words and formats, whatever the system language (GMT for times of day).
nonisolated let english = CopyLanguage.english()
