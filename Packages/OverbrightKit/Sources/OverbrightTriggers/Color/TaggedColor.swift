// OverbrightTriggers/Color/TaggedColor.swift — EDR colour builders for T1.
// ARCHITECTURE.md §4.7 ("EDR colours start from CGColor", T1 tag precision), D4.
//
// PITFALL (seen on macOS 27.0.1, off screen): `NSColor`'s component-array initialiser returns a tagged-pointer colour
// with 8-bit components that WRAP above 1.0 (1.6 becomes 152/255 ≈ 0.596, 4.0 becomes 252/255), for extended sRGB too.
// Every EDR colour here therefore starts from a `CGColor`; a lint test keeps that initialiser out of this module,
// FillLight and Design, and `TaggedColorTests` notices if AppKit ever changes.
import CoreGraphics

/// Grey colours `(v, v, v, 1)` in extended linear sRGB, optionally headroom-tagged.
nonisolated enum TaggedColor {
    /// Tags at or below 1.0001 read back as 1.0 and a layer needs a tag above 1.0 to request EDR (CALayer.h), so a
    /// tag that must request EDR is raised to at least this.
    static let minimumEDRTag = 1.01

    /// Extended linear sRGB (components above 1.0 are brighter than SDR white).
    static func extendedLinearSRGB() -> CGColorSpace? { CGColorSpace(name: CGColorSpace.extendedLinearSRGB) }

    /// `tag` raised to `minimumEDRTag` (a non-finite tag gives the minimum).
    static func edrTag(_ tag: Double) -> Double { tag.isFinite ? max(tag, minimumEDRTag) : minimumEDRTag }

    /// `(v, v, v, 1)` tagged with `headroom` (`CGColorCreateWithContentHeadroom`). The tag is metadata: a black colour
    /// can carry a tag of 16. Nil if the colour space is unavailable.
    @available(macOS 26.0, *)
    static func cgColor(value: Double, headroom: Double) -> CGColor? {
        guard let space = extendedLinearSRGB() else { return nil }
        let v = CGFloat(clampedComponent(value))
        return CGColor(headroom: Float(headroom), colorSpace: space, red: v, green: v, blue: v, alpha: 1)
    }

    /// An untagged extended-range grey: the macOS 14–25 legacy T1 path.
    static func untaggedCGColor(value: Double) -> CGColor? {
        guard let space = extendedLinearSRGB() else { return nil }
        let v = CGFloat(clampedComponent(value))
        return CGColor(colorSpace: space, components: [v, v, v, 1])
    }

    /// A component kept finite and non-negative (extended range allows values above 1).
    static func clampedComponent(_ value: Double) -> Double { value.isFinite ? max(value, 0) : 0 }
}
