// OverbrightFillLight/Color/LinearRGB.swift — a colour in extended linear sRGB. ARCHITECTURE.md §7.6; DESIGN.md §11.

/// A colour in extended linear sRGB (the colour space of `CGColorSpace.extendedLinearSRGB` and of the clear-only
/// Metal drawable). Components may exceed 1.0: that is light above SDR white, shown only with EDR headroom.
public nonisolated struct LinearRGB: Hashable, Sendable {
    /// Red, linear light.
    public var red: Double
    /// Green, linear light.
    public var green: Double
    /// Blue, linear light.
    public var blue: Double

    /// A colour from linear components.
    public init(red: Double, green: Double, blue: Double) {
        self.red = red; self.green = green; self.blue = blue
    }

    /// SDR white (1, 1, 1).
    public static let white = LinearRGB(red: 1, green: 1, blue: 1)

    /// The largest component: the headroom this colour needs to show without clipping.
    public var maximum: Double { max(red, green, blue) }

    /// Every component multiplied by `factor` (the Fill Light's value, ARCHITECTURE.md §7.6).
    public func scaled(by factor: Double) -> LinearRGB {
        LinearRGB(red: red * factor, green: green * factor, blue: blue * factor)
    }
}
