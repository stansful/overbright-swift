// OverbrightDesign/Tokens/GlyphSize.swift — the point sizes of SF Symbols drawn beside text. DESIGN.md §5.4 (the slider
// row), §5.7 (status chips), §5.8 (banners), §5.9 (footer chips), §6 (HUD). Views write
// `.font(.system(size: GlyphSize.chip))`, never a literal size (ARCHITECTURE.md §9.2 rule 3).
import CoreGraphics

/// SF Symbol sizes in points.
public nonisolated enum GlyphSize {
    /// The glyph of a status chip or a footer chip, and the spinner that stands in for it ("Preparing…"): 12 pt.
    public static let chip: CGFloat = 12
    /// A banner's glyph: 14 pt.
    public static let banner: CGFloat = 14
    /// `sun.min` and `sun.max.fill` at the ends of a card's slider row (drawn by the card, not by `BoostSlider`): 14 pt.
    public static let sliderEnd: CGFloat = 14
    /// The HUD's leading glyph: 20 pt.
    public static let hud: CGFloat = 20
}
