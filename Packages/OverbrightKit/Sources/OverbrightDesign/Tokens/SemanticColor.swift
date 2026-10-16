// OverbrightDesign/Tokens/SemanticColor.swift — the tints of chips and banners. DESIGN.md §2.1.
// Seam written by WP0a (ARCHITECTURE.md §10.0); WP9 owns it.
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

    /// The glyph colour.
    public var color: Color {
        switch self {
        case .neutral: Color(nsColor: .secondaryLabelColor)
        case .info: Color(nsColor: .systemBlue)
        case .warning: Color(nsColor: .systemOrange)
        case .danger: Color(nsColor: .systemRed)
        case .success: Color(nsColor: .systemGreen)
        }
    }

    /// The background tint behind chip and banner text.
    public var tint: Color {
        switch self {
        case .neutral: Color(nsColor: .systemGray).opacity(0.15)
        default: color.opacity(0.15)
        }
    }
}
