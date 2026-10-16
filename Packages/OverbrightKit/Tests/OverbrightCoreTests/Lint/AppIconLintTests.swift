// OverbrightCoreTests/Lint/AppIconLintTests.swift — the geometry of the app icon's layers (DESIGN.md §14 "Past white"),
// as `scripts/render-icon.swift` renders them into App/AppIcon.icon/Assets: the bloom is a small hot core with a short
// warm falloff (no wide half-transparent haze, which plus-lighter turns muddy over the graphite), its white is brighter
// than the screen, the screen leans back in perspective instead of being rotated in the image plane, and the warm
// keyline is wide enough to show at 128 px. The layers are 1024 × 1024 PNGs with transparency.
import CoreGraphics
import Foundation
import ImageIO
import Testing

@Suite struct AppIconLintTests {
    /// The 824-pt body of the macOS icon grid on the 1024-pt canvas (the renderer's unit).
    private static let body = 824.0

    @Test func theBloomIsAHotCoreWithoutAWideHaze() throws {
        let bloom = try #require(Layer(named: "bloom.png"))
        let hazy = bloom.count { _, _, pixel in pixel.alpha > 0.2 && pixel.alpha < 0.6 }
        #expect(Double(hazy) / Double(bloom.width * bloom.height) < 0.06, "half-transparent area: \(hazy) px")
        let core = bloom.points { _, _, pixel in pixel.alpha > 0.99 && min(pixel.red, pixel.green, pixel.blue) > 0.99 }
        #expect(!core.isEmpty, "no white-hot core")
        let lit = bloom.points { _, _, pixel in pixel.alpha > 0.02 }
        let center = Self.centroid(core)
        let reach = lit.map { hypot($0.x - center.x, $0.y - center.y) }.max() ?? 0
        #expect(reach < 0.36 * Self.body, "the bloom reaches \(reach) px")
    }

    @Test func theCoreSitsOnTheScreensUpperTrailingCornerAndOutshinesIt() throws {
        let screen = try #require(Layer(named: "screen.png"))
        let bloom = try #require(Layer(named: "bloom.png"))
        let face = screen.points { _, _, pixel in pixel.alpha > 0.99 && Self.isGrey(pixel) }
        let brightest = face.compactMap { screen.pixel(Int($0.x), Int($0.y))?.red }.max() ?? 1
        #expect(brightest < 0.93, "the screen's grey \(brightest) leaves no room for brighter-than-white")
        let opaque = screen.points { _, _, pixel in pixel.alpha > 0.5 }
        let right = opaque.map(\.x).max() ?? 0, top = opaque.map(\.y).min() ?? 0
        let core = Self.centroid(bloom.points { _, _, pixel in pixel.alpha > 0.99 && pixel.red > 0.99 })
        #expect(abs(core.x - right) < 0.06 * Self.body && abs(core.y - top) < 0.06 * Self.body,
                "core at \(core), screen corner at (\(right), \(top))")
    }

    @Test func theScreenLeansBackInsteadOfTurning() throws {
        let screen = try #require(Layer(named: "screen.png"))
        // The screen's face only: the keyline is stroked across its edge and would read as a raised edge.
        func isFace(_ pixel: Pixel?) -> Bool { pixel.map { $0.alpha > 0.5 && Self.isGrey($0) } ?? false }
        let opaque = screen.points { _, _, pixel in isFace(pixel) }
        let left = Int(opaque.map(\.x).min() ?? 0), right = Int(opaque.map(\.x).max() ?? 0)
        let top = Int(opaque.map(\.y).min() ?? 0), bottom = Int(opaque.map(\.y).max() ?? 0)
        // An in-plane rotation lifts one end of the top edge: two points either side of the middle (left of where the
        // keyline starts) meet each edge on the same row. 4° would part them by 6 rows.
        let middle = (left + right) / 2, offset = Int(0.05 * Self.body)
        func edgeRow(atX x: Int, fromTop: Bool) -> Int? {
            let rows = fromTop ? Array(top...bottom) : Array((top...bottom).reversed())
            return rows.first { isFace(screen.pixel(x, $0)) }
        }
        for fromTop in [true, false] {
            let a = try #require(edgeRow(atX: middle - offset, fromTop: fromTop))
            let b = try #require(edgeRow(atX: middle + offset, fromTop: fromTop))
            #expect(abs(a - b) <= 1, "\(fromTop ? "top" : "bottom") edge at rows \(a) and \(b)")
        }
        // The lean: the top edge is narrower than the bottom one.
        func span(atRow y: Int) -> Int {
            let xs = (left...right).filter { isFace(screen.pixel($0, y)) }
            return (xs.max() ?? 0) - (xs.min() ?? 0)
        }
        let inset = Int(0.06 * Self.body)
        #expect(span(atRow: top + inset) < span(atRow: bottom - inset) - 8)
    }

    @Test func theWarmKeylineIsWideEnoughToShowAt128Pixels() throws {
        let screen = try #require(Layer(named: "screen.png"))
        let warm = screen.points { _, _, pixel in Self.isWarm(pixel) }
        #expect(warm.count > 2000, "\(warm.count) warm pixels")
        // Across the top edge, 0.12 of the body before the corner: at least 7 warm rows (a 9-pt line, anti-aliased).
        let right = Int(screen.points { _, _, pixel in pixel.alpha > 0.5 }.map(\.x).max() ?? 0)
        let x = right - Int(0.12 * Self.body)
        let rows = (0..<screen.height).filter { y in screen.pixel(x, y).map(Self.isWarm) ?? false }
        #expect(rows.count >= 7, "keyline \(rows.count) px wide at x \(x)")
    }

    // MARK: Helpers

    private static func isGrey(_ pixel: Pixel) -> Bool {
        max(pixel.red, pixel.green, pixel.blue) - min(pixel.red, pixel.green, pixel.blue) < 0.02
    }

    /// The keyline's #FFB020 (sRGB 1.00, 0.69, 0.13), with room for anti-aliasing against the grey.
    private static func isWarm(_ pixel: Pixel) -> Bool {
        pixel.alpha > 0.9 && pixel.red > 0.9 && pixel.green > 0.55 && pixel.green < 0.85 && pixel.blue < 0.45
    }

    private static func centroid(_ points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        return CGPoint(x: points.map(\.x).reduce(0, +) / CGFloat(points.count),
                       y: points.map(\.y).reduce(0, +) / CGFloat(points.count))
    }
}

/// One straight (unpremultiplied) sRGB pixel, components 0…1.
private struct Pixel {
    var red: Double, green: Double, blue: Double, alpha: Double
}

/// A layer of App/AppIcon.icon/Assets drawn into an sRGB RGBA8 buffer; row 0 is the top of the image.
private struct Layer {
    let width: Int, height: Int
    private let bytes: [UInt8]

    init?(named name: String) {
        let url = SourceScan.repository.appending(path: "App/AppIcon.icon/Assets/\(name)")
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        width = image.width
        height = image.height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(data: raw.baseAddress, width: image.width, height: image.height,
                                          bitsPerComponent: 8, bytesPerRow: image.width * 4, space: space,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard drawn else { return nil }
        bytes = buffer
    }

    func pixel(_ x: Int, _ y: Int) -> Pixel? {
        guard x >= 0, y >= 0, x < width, y < height else { return nil }
        let i = (y * width + x) * 4
        let alpha = Double(bytes[i + 3]) / 255
        guard alpha > 0 else { return Pixel(red: 0, green: 0, blue: 0, alpha: 0) }
        return Pixel(red: Double(bytes[i]) / 255 / alpha, green: Double(bytes[i + 1]) / 255 / alpha,
                     blue: Double(bytes[i + 2]) / 255 / alpha, alpha: alpha)
    }

    func count(where matches: (Int, Int, Pixel) -> Bool) -> Int { points(where: matches).count }

    func points(where matches: (Int, Int, Pixel) -> Bool) -> [CGPoint] {
        var found: [CGPoint] = []
        for y in 0..<height {
            for x in 0..<width {
                if let pixel = pixel(x, y), matches(x, y, pixel) { found.append(CGPoint(x: x, y: y)) }
            }
        }
        return found
    }
}
