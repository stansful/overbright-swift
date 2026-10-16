// OverbrightDesign/Tokens/HitTarget.swift — minimum hit areas. DESIGN.md §2.3.
// Seam written by WP0a (ARCHITECTURE.md §10.0); WP9 owns it. Widening happens inside the button styles, never with an
// outer frame (Cranny gotcha).
import CoreGraphics

/// Minimum hit areas in points.
public nonisolated enum HitTarget {
    /// Every panel control.
    public static let minimum = CGSize(width: 28, height: 24)
    /// The slider thumb's hit area (the thumb itself is 20 pt).
    public static let sliderThumb: CGFloat = 28
    /// Footer chips are at least this wide.
    public static let footerChipWidth: CGFloat = 28
}
