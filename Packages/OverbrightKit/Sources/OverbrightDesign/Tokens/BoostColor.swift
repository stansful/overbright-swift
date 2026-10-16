// OverbrightDesign/Tokens/BoostColor.swift — the one warm colour of the boost zone and the slider's other marks.
// DESIGN.md §2.1. Seam written by WP0a (ARCHITECTURE.md §10.0); WP9 owns it (incl. the contrast audit tests).
import AppKit
import SwiftUI

/// Colours of the level slider and the HUD bar. `warm` is never text, never a background behind text, never a status
/// and never shown while Overbright is off or paused.
public nonisolated enum BoostColor {
    /// The fill right of the detent while extra light is on screen: #B35F00 / #FFB020, Increase Contrast
    /// #8F4A00 / #FFC65C.
    public static let warm = Color(nsColor: NSColor(name: "OverbrightBoostWarm") { appearance in
        switch appearance.bestMatch(from: [.aqua, .darkAqua, .accessibilityHighContrastAqua,
                                           .accessibilityHighContrastDarkAqua]) {
        case .darkAqua: NSColor(srgbRed: 1, green: 0xB0 / 255, blue: 0x20 / 255, alpha: 1)
        case .accessibilityHighContrastAqua: NSColor(srgbRed: 0x8F / 255, green: 0x4A / 255, blue: 0, alpha: 1)
        case .accessibilityHighContrastDarkAqua: NSColor(srgbRed: 1, green: 0xC6 / 255, blue: 0x5C / 255, alpha: 1)
        default: NSColor(srgbRed: 0xB3 / 255, green: 0x5F / 255, blue: 0, alpha: 1)
        }
    })
    /// The slider track.
    public static let track = Color(nsColor: .systemFill)
    /// The Standard detent mark, preset ticks and the dim fill.
    public static let mark = Color(nsColor: .secondaryLabelColor)
    /// The allowed-now marker.
    public static let allowedMarker = Color(nsColor: .labelColor)
}
