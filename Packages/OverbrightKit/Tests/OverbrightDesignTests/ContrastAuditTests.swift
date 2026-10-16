// OverbrightDesignTests/ContrastAuditTests.swift — DESIGN.md §2.1's contrast audit (WCAG 2.x, non-text 3:1 by 1.4.11,
// text 4.5:1 by 1.4.3): the reference table reproduced from the tokens, then every token re-measured against the system
// colours it resolves to in Light, Dark and Increase Contrast, and the "Off" readout as `ReadoutText` draws it on the
// card. ARCHITECTURE.md §10.11 Acceptance.
import AppKit
import OverbrightPolicy
import SwiftUI
import Testing
@testable import OverbrightDesign

@MainActor @Suite struct ContrastAuditTests {
    // The reference backgrounds of DESIGN.md §2.1.
    nonisolated static let lightPanel = SRGBA(hex: 0xF2F2F2), lightCard = SRGBA(hex: 0xFFFFFF), lightTrack = SRGBA(hex: 0xDCDCDC)
    nonisolated static let darkPanel = SRGBA(hex: 0x1E1E1E), darkCard = SRGBA(hex: 0x2C2C2E), darkTrack = SRGBA(hex: 0x48484A)
    // `secondaryLabelColor` as black 50 % / white 55 %, `labelColor` 85 %, `systemGray` #8E8E93.
    nonisolated static let secondaryLight = SRGBA.black.opacity(0.5), secondaryDark = SRGBA.white.opacity(0.55)
    nonisolated static let labelLight = SRGBA.black.opacity(0.85), labelDark = SRGBA.white.opacity(0.85)
    nonisolated static let systemGray = SRGBA(hex: 0x8E8E93)

    /// The table's figures are given to two decimals.
    private func expect(_ measured: Double, _ table: Double, _ what: String,
                        sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(abs(measured - table) < 0.006, "\(what): measured \(measured), DESIGN.md §2.1 says \(table)",
                sourceLocation: sourceLocation)
    }

    // MARK: The reference table

    @Test func boostWarmMatchesTheTable() {
        let light = OverbrightColor.boostWarm(dark: false, highContrast: false)
        let dark = OverbrightColor.boostWarm(dark: true, highContrast: false)
        #expect(light == SRGBA(hex: 0xB35F00))
        #expect(dark == SRGBA(hex: 0xFFB020))
        expect(light.contrast(with: Self.lightTrack), 3.36, "warm vs light track")
        expect(light.contrast(with: Self.lightCard), 4.61, "warm vs light card")
        expect(light.contrast(with: Self.lightPanel), 4.12, "warm vs light panel")
        expect(dark.contrast(with: Self.darkTrack), 4.99, "warm vs dark track")
        expect(dark.contrast(with: Self.darkCard), 7.62, "warm vs dark card")
        expect(dark.contrast(with: Self.darkPanel), 9.12, "warm vs dark panel")
    }

    @Test func boostWarmIncreaseContrastMatchesTheTable() {
        let light = OverbrightColor.boostWarm(dark: false, highContrast: true)
        let dark = OverbrightColor.boostWarm(dark: true, highContrast: true)
        #expect(light == SRGBA(hex: 0x8F4A00))
        #expect(dark == SRGBA(hex: 0xFFC65C))
        expect(light.contrast(with: Self.lightTrack), 4.87, "IC warm vs light track")
        expect(light.contrast(with: Self.lightCard), 6.67, "IC warm vs light card")
        expect(dark.contrast(with: Self.darkTrack), 5.86, "IC warm vs dark track")
        expect(dark.contrast(with: Self.darkCard), 8.95, "IC warm vs dark card")
    }

    /// `dimFill`, `tick`, the hatch lines and `detentMark`: secondary over the track.
    @Test func secondaryMarksMatchTheTable() {
        let light = Self.secondaryLight.over(Self.lightTrack), dark = Self.secondaryDark.over(Self.darkTrack)
        expect(light.contrast(with: Self.lightTrack), 3.72, "secondary vs light track")
        expect(light.contrast(with: Self.lightCard), 5.10, "secondary vs light card")
        expect(dark.contrast(with: Self.darkTrack), 4.07, "secondary vs dark track")
        expect(dark.contrast(with: Self.darkCard), 6.22, "secondary vs dark card")
    }

    @Test func allowedMarkerMatchesTheTable() {
        let light = Self.labelLight.over(Self.lightTrack), dark = Self.labelDark.over(Self.darkTrack)
        expect(light.contrast(with: Self.lightTrack), 11.74, "marker vs light track")
        expect(light.contrast(with: Self.lightCard), 16.10, "marker vs light card")
        expect(dark.contrast(with: Self.darkTrack), 7.18, "marker vs dark track")
        expect(dark.contrast(with: Self.darkCard), 10.96, "marker vs dark card")
    }

    @Test func neutralChipMatchesTheTable() {
        let lightTint = Self.systemGray.opacity(0.15).over(Self.lightCard)
        let darkTint = Self.systemGray.opacity(0.15).over(Self.darkCard)
        expect(Self.secondaryLight.over(lightTint).contrast(with: lightTint), 3.86, "neutral glyph, light")
        expect(Self.labelLight.over(lightTint).contrast(with: lightTint), 13.39, "neutral text, light")
        expect(Self.secondaryDark.over(darkTint).contrast(with: darkTint), 4.65, "neutral glyph, dark")
        expect(Self.labelDark.over(darkTint).contrast(with: darkTint), 8.63, "neutral text, dark")
    }

    /// The v0.1 tokens failed (`tertiaryLabelColor` 1.88:1 on the light card, `quaternaryLabelColor` 1.25:1): the
    /// harness has to see that, or its passes mean nothing.
    @Test func theRetiredTokensFail() {
        let tertiary = SRGBA.black.opacity(0.26).over(Self.lightCard)
        #expect(tertiary.contrast(with: Self.lightCard) < 3)
        #expect(SRGBA(hex: 0xFF9500).contrast(with: Self.lightCard) < 3)           // system orange in Light
        // Why the "Off" readout is `labelColor`: `tertiaryLabelColor` fails 4.5:1 on both cards, and so does
        // `secondaryLabelColor` on the light one (3.95:1), however light the card is.
        #expect(SRGBA.white.opacity(0.25).over(Self.darkCard).contrast(with: Self.darkCard) < 4.5)
        #expect(Self.secondaryLight.over(Self.lightCard).contrast(with: Self.lightCard) < 4.5)
    }

    // MARK: The resolved system colours

    /// Every mark against the track it sits on and the card around it, every glyph against its tint, the chip text
    /// against its tint, in Light, Dark, Increase Contrast Light and Increase Contrast Dark.
    @Test(arguments: [OverbrightTheme.Palette.standard, .highContrast, .opaque], [ColorScheme.light, .dark])
    func resolvedTokensKeepTheirContrast(palette: OverbrightTheme.Palette, scheme: ColorScheme) {
        func value(_ token: OverbrightColor) -> SRGBA { token.resolved(palette: palette, scheme: scheme) }
        let panel = value(.panelBackground)
        #expect(panel.alpha == 1, "\(palette) \(scheme): the panel stand-in is opaque")
        let card = value(.card).over(panel)
        let track = value(.track).over(card)
        let where_ = "\(palette), \(scheme)"
        for token in [OverbrightColor.boostWarm, .dimFill, .tick, .detentMark, .inactiveHatch, .allowedMarker] {
            let mark = value(token).over(track)
            #expect(mark.contrast(with: track) >= 3, "\(token) vs track, \(where_): \(mark.contrast(with: track))")
            #expect(mark.contrast(with: card) >= 3, "\(token) vs card, \(where_): \(mark.contrast(with: card))")
        }
        let tint = value(.neutralTint).over(card)
        let glyph = value(.neutralGlyph).over(tint)
        #expect(glyph.contrast(with: tint) >= 3, "neutral glyph vs tint, \(where_)")
        let text = (SRGBA(NSColor.labelColor.resolved(scheme, palette)) ?? .black).over(tint)
        #expect(text.contrast(with: tint) >= 4.5, "chip text vs tint, \(where_)")
        // The readout, "Off" included, is text on the card (WCAG 1.4.3).
        let readout = (SRGBA(NSColor.labelColor.resolved(scheme, palette)) ?? .black).over(card)
        #expect(readout.contrast(with: card) >= 4.5, "readout vs card, \(where_): \(readout.contrast(with: card))")
    }

    /// The "Off" readout, shown at every launch, as `ReadoutText` draws it on the card: its ink reaches 4.5:1 in every
    /// palette and appearance (it was `tertiaryLabelColor`, 2.5:1 on the dark card).
    @Test(arguments: [OverbrightTheme.Palette.standard, .highContrast, .opaque], [ColorScheme.light, .dark])
    func theOffReadoutIsReadableOnTheCard(palette: OverbrightTheme.Palette, scheme: ColorScheme) throws {
        let panel = OverbrightColor.panelBackground.resolved(palette: palette, scheme: scheme)
        let card = OverbrightColor.card.resolved(palette: palette, scheme: scheme).over(panel)
        let off = ReadoutValues(state: .off, appliedGain: 1, requestedGain: nil, nits: nil, preset: nil, isEstimate: true,
                                dimPercent: nil)
        let theme = OverbrightTheme(reduceTransparency: palette == .opaque, increaseContrast: palette == .highContrast)
        let pixels = try render(ReadoutText(off), size: CGSize(width: 80, height: 24), theme: theme, scheme: scheme,
                                background: card.color)
        var strongest = 1.0
        for y in 0..<pixels.height {
            for x in 0..<pixels.width {
                let p = pixels.pixel(x: x, y: y)
                strongest = max(strongest, SRGBA(red: p.r, green: p.g, blue: p.b).contrast(with: card))
            }
        }
        #expect(strongest >= 4.5, "\(palette), \(scheme): the “Off” ink reaches \(strongest):1 on \(card)")
    }

    /// Increase Contrast draws the marks in `labelColor` and the warm colour darker or lighter (DESIGN.md §2.1, §15).
    @Test func increaseContrastStrengthensTheMarks() {
        for scheme in [ColorScheme.light, .dark] {
            let standard = OverbrightColor.tick.resolved(palette: .standard, scheme: scheme)
            let high = OverbrightColor.tick.resolved(palette: .highContrast, scheme: scheme)
            #expect(high.alpha > standard.alpha, "\(scheme): ticks in labelColor")
            let card = OverbrightColor.card.resolved(palette: .highContrast, scheme: scheme)
            #expect(card.alpha == 1, "\(scheme): opaque cards under Increase Contrast")
            #expect(OverbrightColor.cardStroke.resolved(palette: .highContrast, scheme: scheme).alpha
                    > OverbrightColor.cardStroke.resolved(palette: .standard, scheme: scheme).alpha)
        }
    }
}

private extension NSColor {
    /// The colour in the appearance a palette and scheme resolve to.
    @MainActor func resolved(_ scheme: ColorScheme, _ palette: OverbrightTheme.Palette) -> NSColor {
        let name: NSAppearance.Name = switch (scheme == .dark, palette == .highContrast) {
        case (false, false): .aqua
        case (true, false): .darkAqua
        case (false, true): .accessibilityHighContrastAqua
        case (true, true): .accessibilityHighContrastDarkAqua
        }
        var result = self
        NSAppearance(named: name)?.performAsCurrentDrawingAppearance { result = self.usingColorSpace(.sRGB) ?? self }
        return result
    }
}
