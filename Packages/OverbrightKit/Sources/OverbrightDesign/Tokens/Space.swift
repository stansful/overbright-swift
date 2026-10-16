// OverbrightDesign/Tokens/Space.swift — spacing tokens (Cranny's scale). DESIGN.md §2.3.
// Seam written by WP0a (ARCHITECTURE.md §10.0); WP9 owns it.
import CoreGraphics

/// Spacing in points. Views never write a literal spacing (DESIGN.md §2.0 rule 1).
public nonisolated enum Space {
    /// 2 pt.
    public static let xxs: CGFloat = 2
    /// 4 pt.
    public static let xs: CGFloat = 4
    /// 6 pt.
    public static let s: CGFloat = 6
    /// 8 pt.
    public static let m: CGFloat = 8
    /// 12 pt.
    public static let l: CGFloat = 12
    /// 16 pt.
    public static let xl: CGFloat = 16
    /// 20 pt.
    public static let xxl: CGFloat = 20
    /// 24 pt.
    public static let xxxl: CGFloat = 24
    /// 32 pt.
    public static let huge: CGFloat = 32
}
