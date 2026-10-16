// OverbrightDesign/Tokens/Radius.swift — corner radii (always `.continuous`, concentric). DESIGN.md §2.3.
// Seam written by WP0a (ARCHITECTURE.md §10.0); WP9 owns it.
import CoreGraphics

/// Corner radii in points; macOS 26 and later use the larger values of DESIGN.md §2.3.
public nonisolated enum Radius {
    /// The panel container.
    public static var panel: CGFloat { modern ? 20 : 16 }
    /// Display cards and banners (inset 8 from the panel).
    public static var card: CGFloat { modern ? 12 : 8 }
    /// Small controls.
    public static let control: CGFloat = 6
    /// The HUD.
    public static var hud: CGFloat { modern ? 20 : 16 }
    /// Key caps.
    public static let keycap: CGFloat = 4
    /// How far the focus ring sits outside its element.
    public static let focusRingOutset: CGFloat = 3

    private static var modern: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }
}
