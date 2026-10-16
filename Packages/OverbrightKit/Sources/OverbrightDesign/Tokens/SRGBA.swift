// OverbrightDesign/Tokens/SRGBA.swift — sRGB colour values with alpha, compositing and the WCAG 2.x contrast ratio.
// DESIGN.md §2.1 (the contrast audit), App. B. The audit composites a token over what is next to it the way an 8-bit
// framebuffer stores the result, then compares relative luminances.
import AppKit
import SwiftUI

/// An sRGB colour (components 0…1, gamma-encoded) with alpha: the resolved value of a colour token.
public nonisolated struct SRGBA: Hashable, Sendable, CustomStringConvertible {
    /// Red, gamma-encoded.
    public var red: Double
    /// Green, gamma-encoded.
    public var green: Double
    /// Blue, gamma-encoded.
    public var blue: Double
    /// Coverage.
    public var alpha: Double

    /// A colour from components 0…1.
    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }

    /// An opaque colour from `0xRRGGBB`.
    public init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    /// A grey (or white or black) at `alpha`.
    public init(white: Double, alpha: Double = 1) { self.init(red: white, green: white, blue: white, alpha: alpha) }

    /// Black.
    public static let black = SRGBA(white: 0)
    /// White.
    public static let white = SRGBA(white: 1)

    /// `nsColor` in sRGB, nil when it has no sRGB representation (a pattern colour).
    public init?(_ nsColor: NSColor) {
        guard let c = nsColor.usingColorSpace(.sRGB) else { return nil }
        self.init(red: Double(c.redComponent), green: Double(c.greenComponent), blue: Double(c.blueComponent),
                  alpha: Double(c.alphaComponent))
    }

    /// The same colour at `opacity` × its alpha (a token such as "`separatorColor` 50 %").
    public func opacity(_ opacity: Double) -> SRGBA {
        SRGBA(red: red, green: green, blue: blue, alpha: alpha * opacity)
    }

    /// This colour drawn over `background` ("source over" in sRGB), as an 8-bit framebuffer stores the pixel.
    /// The result takes the background's alpha (an opaque background gives an opaque pixel).
    public func over(_ background: SRGBA) -> SRGBA {
        func mix(_ f: Double, _ b: Double) -> Double { Self.quantized(f * alpha + b * (1 - alpha)) }
        return SRGBA(red: mix(red, background.red), green: mix(green, background.green),
                     blue: mix(blue, background.blue), alpha: background.alpha)
    }

    /// WCAG 2.x relative luminance of the colour as an opaque pixel.
    public var relativeLuminance: Double {
        func linear(_ c: Double) -> Double {
            let v = min(max(c, 0), 1)
            return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG 2.x contrast ratio (1…21) between this colour and `other`, both as opaque pixels.
    public func contrast(with other: SRGBA) -> Double {
        let a = relativeLuminance, b = other.relativeLuminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// The SwiftUI colour (sRGB).
    public var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha) }

    /// "#RRGGBB" (+ alpha percent when translucent), for test messages and diagnostics.
    public var description: String {
        let hex = String(format: "#%02X%02X%02X", Int((red * 255).rounded()), Int((green * 255).rounded()),
                         Int((blue * 255).rounded()))
        return alpha < 1 ? "\(hex) \(Int((alpha * 100).rounded())) %" : hex
    }

    private static func quantized(_ value: Double) -> Double { (min(max(value, 0), 1) * 255).rounded() / 255 }
}
