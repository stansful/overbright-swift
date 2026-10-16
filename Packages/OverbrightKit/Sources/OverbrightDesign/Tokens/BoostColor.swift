// OverbrightDesign/Tokens/BoostColor.swift — the one warm colour of the boost zone and the slider's other marks, as
// appearance-following colours for surfaces that have no `OverbrightTheme` (AppKit drawing). DESIGN.md §2.1.
// Seam written by WP0a (ARCHITECTURE.md §10.0); WP9 owns it. SwiftUI views use `theme.color(_:)` instead, which also
// honours the Increase Contrast palette of the theme.
import AppKit
import SwiftUI

/// Colours of the level slider and the HUD bar. `warm` is never text, never a background behind text, never a status
/// and never shown while Overbright is off or paused.
public nonisolated enum BoostColor {
    /// The fill right of the detent while extra light is on screen: #B35F00 / #FFB020, Increase Contrast
    /// #8F4A00 / #FFC65C.
    public static let warm = Color(nsColor: warmNSColor)

    /// `warm` for AppKit drawing (the HUD bar, the status symbol's glow is a template and never uses it).
    public static let warmNSColor = NSColor(name: "OverbrightBoostWarm") { appearance in
        let match = appearance.bestMatch(from: [.aqua, .darkAqua, .accessibilityHighContrastAqua,
                                                .accessibilityHighContrastDarkAqua])
        let dark = match == .darkAqua || match == .accessibilityHighContrastDarkAqua
        let highContrast = match == .accessibilityHighContrastAqua || match == .accessibilityHighContrastDarkAqua
        let value = OverbrightColor.boostWarm(dark: dark, highContrast: highContrast)
        return NSColor(srgbRed: value.red, green: value.green, blue: value.blue, alpha: 1)
    }

    /// The slider track.
    public static let track = Color(nsColor: .systemFill)
    /// The Standard detent mark, preset ticks and the dim fill.
    public static let mark = Color(nsColor: .secondaryLabelColor)
    /// The allowed-now marker.
    public static let allowedMarker = Color(nsColor: .labelColor)
}
