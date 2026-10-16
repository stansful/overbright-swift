// OverbrightDesign/Theme/OverbrightTheme.swift — the one environment value every Overbright view reads.
// DESIGN.md §2.0 rule 2, §2.5, §3.1–§3.2; ARCHITECTURE.md §10.0 (Design seam).
// Seam written by WP0a: the type, its members and `.overbrightThemeRoot(_:)` are fixed; WP9 owns the body (palette
// rules, glass availability, the Reduce Motion variants of every motion kind).
import SwiftUI

/// The merged appearance and accessibility state of one surface (panel, HUD, Settings, Welcome, …). Views read
/// `@Environment(\.overbright)` and never raw accessibility flags; `.overbrightThemeRoot(_:)` fills it once per surface.
public nonisolated struct OverbrightTheme: Hashable, Sendable {
    /// Which colour set the tokens resolve to (DESIGN.md §2.1).
    public enum Palette: Hashable, Sendable {
        /// System materials and colours.
        case standard
        /// Increase Contrast: opaque cards with a full-strength hairline.
        case highContrast
        /// Reduce Transparency: opaque backgrounds instead of materials.
        case opaque
    }

    /// Reduce Motion: cross-fades only, no slides, scales or symbol effects (DESIGN.md §3.2).
    public var reduceMotion: Bool
    /// Reduce Transparency: no materials or glass.
    public var reduceTransparency: Bool
    /// Increase Contrast.
    public var increaseContrast: Bool
    /// Differentiate Without Color.
    public var differentiateWithoutColor: Bool
    /// VoiceOver is running.
    public var voiceOverRunning: Bool
    /// The effective appearance.
    public var colorScheme: ColorScheme
    /// Left to right, or right to left (the slider and the panel mirror; the status symbol does not).
    public var layoutDirection: LayoutDirection

    /// A theme; `.overbrightThemeRoot(_:)` merges the live system state into it.
    public init(reduceMotion: Bool = false, reduceTransparency: Bool = false, increaseContrast: Bool = false,
                differentiateWithoutColor: Bool = false, voiceOverRunning: Bool = false,
                colorScheme: ColorScheme = .light, layoutDirection: LayoutDirection = .leftToRight) {
        self.reduceMotion = reduceMotion; self.reduceTransparency = reduceTransparency
        self.increaseContrast = increaseContrast; self.differentiateWithoutColor = differentiateWithoutColor
        self.voiceOverRunning = voiceOverRunning; self.colorScheme = colorScheme; self.layoutDirection = layoutDirection
    }

    /// The animation of `kind`, or nil when motion must not play (Reduce Motion). WP9 adds the short cross-fade
    /// variants of DESIGN.md §3.2.
    public func animation(_ kind: OverbrightMotion.Kind) -> Animation? {
        reduceMotion ? nil : kind.animation
    }

    /// Symbols may animate on a state change (never in loops, never under Reduce Motion; DESIGN.md §13.1).
    public var animatesSymbols: Bool { !reduceMotion }

    /// The colour set the tokens resolve to.
    public var palette: Palette {
        if increaseContrast { return .highContrast }
        if reduceTransparency { return .opaque }
        return .standard
    }

    /// Liquid Glass on the panel and HUD containers (macOS 26+, not with Reduce Transparency or Increase Contrast).
    public var usesGlass: Bool {
        guard #available(macOS 26, *) else { return false }
        return palette == .standard
    }
}
