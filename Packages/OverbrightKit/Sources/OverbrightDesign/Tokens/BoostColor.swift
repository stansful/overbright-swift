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

    /// `warm` for AppKit drawing (the HUD bar, the status symbol's glow is a template and never uses it). AppKit may
    /// run the provider on any thread that resolves the colour; it only reads its argument and constants.
    public static let warmNSColor = NSColor(name: "OverbrightBoostWarm") { appearance in
        let value = warm(matching: appearance.bestMatch(from: appearanceNames))
        return NSColor(srgbRed: value.red, green: value.green, blue: value.blue, alpha: 1)
    }

    /// The appearances `warmNSColor` tells apart.
    static let appearanceNames: [NSAppearance.Name] = [.aqua, .darkAqua, .accessibilityHighContrastAqua,
                                                       .accessibilityHighContrastDarkAqua]

    /// The warm colour for an appearance's best match among `appearanceNames` (nil: light).
    static func warm(matching name: NSAppearance.Name?) -> SRGBA {
        let dark = name == .darkAqua || name == .accessibilityHighContrastDarkAqua
        let highContrast = name == .accessibilityHighContrastAqua || name == .accessibilityHighContrastDarkAqua
        return OverbrightColor.boostWarm(dark: dark, highContrast: highContrast)
    }

    /// The slider track.
    public static let track = Color(nsColor: .systemFill)
    /// The Standard detent mark, preset ticks and the dim fill.
    public static let mark = Color(nsColor: .secondaryLabelColor)
    /// The allowed-now marker.
    public static let allowedMarker = Color(nsColor: .labelColor)
}
