// OverbrightFillLight/Window/EDRColor.swift — the frame's colours as CGColor. ARCHITECTURE.md §4.7 ("EDR colours start
// from CGColor": NSColor's component initialiser stores 8-bit components and wraps values above 1.0), §7.6.
import CoreGraphics

/// Builds the frame's colours in extended linear sRGB.
nonisolated enum EDRColor {
    /// `kCGColorSpaceExtendedLinearSRGB`, the space of `LinearRGB`.
    static func space() -> CGColorSpace? { CGColorSpace(name: CGColorSpace.extendedLinearSRGB) }

    /// `rgb` tagged with the content headroom `headroom` (at least 1.01, §4.7): components above 1.0 survive and the
    /// tag, on a layer with `preferredDynamicRange = .high`, asks macOS for EDR headroom (macOS 26+).
    @available(macOS 26.0, *)
    static func tagged(_ rgb: LinearRGB, headroom: Double) -> CGColor? {
        guard let space = space() else { return nil }
        let tag = Float(max(headroom, FillLightStyle.minimumHeadroomRequest))
        return CGColor(headroom: tag, colorSpace: space, red: CGFloat(rgb.red), green: CGFloat(rgb.green),
                       blue: CGFloat(rgb.blue), alpha: 1)
    }

    /// `rgb` without a tag: ordinary (SDR) content.
    static func untagged(_ rgb: LinearRGB) -> CGColor? {
        guard let space = space() else { return nil }
        let components: [CGFloat] = [CGFloat(rgb.red), CGFloat(rgb.green), CGFloat(rgb.blue), 1]
        return CGColor(colorSpace: space, components: components)
    }
}
