// OverbrightDesign/Tokens/OverbrightColor.swift — the colour tokens of DESIGN.md §2.1, resolved per palette and
// appearance. System colours carry everything except the boost zone; Overbright ships no accent colour. Every token is
// resolved from the system colour it names (in the appearance of the theme), so the contrast audit measures exactly
// what the views draw (ContrastAuditTests).
import AppKit
import SwiftUI

/// One colour token of DESIGN.md §2.1. Views draw `theme.color(.track)`, never a literal colour.
public nonisolated enum OverbrightColor: String, CaseIterable, Sendable {
    /// The panel and HUD background where no material is drawn (Reduce Transparency, Increase Contrast).
    case panelBackground
    /// Display cards and banners.
    case card
    /// The card edge hairline.
    case cardStroke
    /// The slider track.
    case track
    /// The Standard tick.
    case detentMark
    /// Preset ticks.
    case tick
    /// The slider fill left of the detent.
    case dimFill
    /// The fill right of the detent while extra light is on screen, and the HUD bar. Never text, never behind text,
    /// never a status, never while off or paused.
    case boostWarm
    /// The lines of the 45° hatch: off or paused, beyond the allowed-now marker, a boost half that is off.
    case inactiveHatch
    /// Where the thumb will stop now.
    case allowedMarker
    /// The glyph of neutral chips and banners.
    case neutralGlyph
    /// The tint behind neutral chips and banners.
    case neutralTint
    /// The slider thumb and the welcome card's divider handle: white in every appearance (DESIGN.md §2.4).
    case thumb

    /// The boost-zone colour of DESIGN.md §2.1: light, dark, and their Increase Contrast variants.
    public static func boostWarm(dark: Bool, highContrast: Bool) -> SRGBA {
        switch (dark, highContrast) {
        case (false, false): SRGBA(hex: 0xB35F00)
        case (true, false): SRGBA(hex: 0xFFB020)
        case (false, true): SRGBA(hex: 0x8F4A00)
        case (true, true): SRGBA(hex: 0xFFC65C)
        }
    }

    /// The token as drawn in `palette` and `scheme`: system colours resolved in the matching appearance (the
    /// accessibility appearances under Increase Contrast, so the system's own high-contrast values apply).
    @MainActor public func resolved(palette: OverbrightTheme.Palette, scheme: ColorScheme) -> SRGBA {
        let dark = scheme == .dark
        let highContrast = palette == .highContrast
        if self == .boostWarm { return Self.boostWarm(dark: dark, highContrast: highContrast) }
        let name: NSAppearance.Name = switch (dark, highContrast) {
        case (false, false): .aqua
        case (true, false): .darkAqua
        case (false, true): .accessibilityHighContrastAqua
        case (true, true): .accessibilityHighContrastDarkAqua
        }
        var value = SRGBA.black
        let appearance = NSAppearance(named: name) ?? NSAppearance.currentDrawing()
        appearance.performAsCurrentDrawingAppearance {
            value = systemValue(highContrast: highContrast)
        }
        return value
    }

    /// The SwiftUI colour of the token in `theme` (its palette and appearance).
    @MainActor public func color(in theme: OverbrightTheme) -> Color {
        resolved(palette: theme.palette, scheme: theme.colorScheme).color
    }

    /// The system colour behind the token, in the current drawing appearance.
    private func systemValue(highContrast: Bool) -> SRGBA {
        func system(_ color: NSColor, _ opacity: Double = 1) -> SRGBA {
            (SRGBA(color) ?? .black).opacity(opacity)
        }
        switch self {
        case .panelBackground: return system(.windowBackgroundColor)
        case .card: return highContrast ? system(.controlBackgroundColor) : system(.quaternarySystemFill)
        case .cardStroke: return system(.separatorColor, highContrast ? 1 : 0.5)
        case .track: return highContrast ? system(.secondaryLabelColor, 0.35) : system(.systemFill)
        case .detentMark, .tick, .dimFill, .inactiveHatch, .neutralGlyph:
            return highContrast ? system(.labelColor) : system(.secondaryLabelColor)
        case .allowedMarker: return system(.labelColor)
        case .neutralTint: return system(.systemGray, SemanticColor.chipTintOpacity)
        case .boostWarm: return Self.boostWarm(dark: false, highContrast: highContrast)
        case .thumb: return .white
        }
    }
}
