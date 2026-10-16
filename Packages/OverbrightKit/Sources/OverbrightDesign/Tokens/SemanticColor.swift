// OverbrightDesign/Tokens/SemanticColor.swift — the glyph colours and tints of chips and banners. DESIGN.md §2.1.
// Seam written by WP0a (ARCHITECTURE.md §10.0); WP9 owns it. A semantic colour is always paired with words: chip and
// banner text is `labelColor` on the tint, so text contrast is the system's own and the glyph is redundant.
import AppKit
import SwiftUI

/// Chip and banner glyph colours, always paired with text (text itself uses `labelColor` on a 15 % tint).
public nonisolated enum SemanticColor: String, CaseIterable, Sendable {
    /// Neutral chips and banners (`secondaryLabelColor` glyph on a `systemGray` tint).
    case neutral
    /// Information.
    case info
    /// A limit or a pause.
    case warning
    /// A stop that needs attention.
    case danger
    /// Something worked.
    case success

    /// The tint behind chip text: 15 % of the semantic colour (DESIGN.md §5.7).
    public static let chipTintOpacity = 0.15
    /// The tint of a banner's card: 10 % of the semantic colour (DESIGN.md §5.8).
    public static let bannerTintOpacity = 0.10

    /// The glyph colour (system colours follow Light, Dark and the system's Increase Contrast by themselves).
    public var color: Color { Color(nsColor: nsColor) }

    /// The glyph colour in `theme`: neutral glyphs use `labelColor` under Increase Contrast (DESIGN.md §2.1).
    @MainActor public func glyph(in theme: OverbrightTheme) -> Color {
        self == .neutral ? OverbrightColor.neutralGlyph.color(in: theme) : color
    }

    /// The background tint behind chip text.
    public var tint: Color { tint(opacity: Self.chipTintOpacity) }

    /// The tint of a banner card.
    public var bannerTint: Color { tint(opacity: Self.bannerTintOpacity) }

    /// The AppKit colour behind `color`.
    public var nsColor: NSColor {
        switch self {
        case .neutral: .secondaryLabelColor
        case .info: .systemBlue
        case .warning: .systemOrange
        case .danger: .systemRed
        case .success: .systemGreen
        }
    }

    private func tint(opacity: Double) -> Color {
        switch self {
        case .neutral: Color(nsColor: .systemGray).opacity(opacity)
        default: color.opacity(opacity)
        }
    }
}
