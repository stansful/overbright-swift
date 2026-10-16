// OverbrightDesign/Copy/SafeLimitText.swift — what Safe means on a display, by class. DESIGN.md §12.2 ("Safe sentences
// by class"), §7.4 (the Limit footnote); ARCHITECTURE.md §5.3–§5.5. Nits appear only with a trusted SDR white.
import Foundation
import OverbrightCore
import OverbrightPolicy

/// The Safe sentence of one display: the `safeLimit` chip's popover and Settings ▸ Displays ▸ Limit.
public nonisolated struct SafeLimitText: Hashable, Sendable {
    /// The display's hardware class.
    public var panelClass: PanelClass
    /// The display counts as OLED (detected, or the user's override).
    public var isOLED: Bool
    /// The top of the boost half in Safe at full brightness (`DisplayVerdict.supported(safeGain:)`); nil when Safe
    /// adds nothing (Studio Display XDR).
    public var safeTop: Double?
    /// Trusted SDR white in nits; nil hides nits.
    public var sdrWhiteNits: Double?
    /// The live Safe bound is below the slider's top now (bright surroundings: macOS already shows white that bright).
    public var liveBoundBelowTop: Bool
    /// How Safe is bounded without an SDR estimate (`GainCeiling.safeBound`).
    public var safeBound: GainCeiling.SafeBound

    /// The facts behind the sentence.
    public init(panelClass: PanelClass, isOLED: Bool, safeTop: Double?, sdrWhiteNits: Double? = nil,
                liveBoundBelowTop: Bool = false, safeBound: GainCeiling.SafeBound = GainCeiling.safeBound) {
        self.panelClass = panelClass; self.isOLED = isOLED; self.safeTop = safeTop; self.sdrWhiteNits = sdrWhiteNits
        self.liveBoundBelowTop = liveBoundBelowTop; self.safeBound = safeBound
    }

    /// The sentence.
    public func sentence(in language: CopyLanguage = .app) -> String {
        let (b, l) = (language.bundle, language.locale)
        if isOLED || panelClass == .oledExternal {
            let gain = CopyFormat.roughNumber(GainCeiling.safeGainOLED, in: language)
            return String(localized: "Safe stops at \(gain) times on OLED displays.", bundle: b, locale: l,
                          comment: "Panel ▸ Display card: Safe on an OLED display; the argument is a multiplier such as 1.3")
        }
        guard let top = safeTop, top >= 1.05 else { return Self.addsNothing(in: language) }
        let shown = CopyFormat.multiplier(top, in: language)
        switch panelClass {
        case .builtInXDR, .appleXDRExternal:
            if liveBoundBelowTop {
                return String(localized: "Safe stays at the level this display can hold across the whole screen. In bright surroundings macOS already shows white that bright, so Safe adds nothing now.",
                              bundle: b, locale: l, comment: "Panel ▸ Display card: Safe on an Apple XDR panel in bright surroundings")
            }
            if safeBound == .sliderTopOnly {
                return String(localized: "Safe stays at \(shown) here.", bundle: b, locale: l,
                              comment: "Panel ▸ Display card: Safe when it is bounded by the slider’s top only; the argument is a multiplier such as ×1.67")
            }
            if sdrWhiteNits != nil {
                let nits = CopyFormat.roundedNits(GainCeiling.safeNitsAppleXDR)
                return String(localized: "Safe stays at the level this display can hold across the whole screen, \(shown) here, about \(nits) nits.",
                              bundle: b, locale: l,
                              comment: "Panel ▸ Display card: Safe on an Apple XDR panel with a known SDR white; a multiplier such as ×1.67, then nits")
            }
            return String(localized: "Safe stays at the level this display can hold across the whole screen, \(shown) here.",
                          bundle: b, locale: l,
                          comment: "Panel ▸ Display card: Safe on an Apple XDR panel; the argument is a multiplier such as ×1.67")
        default:
            return String(localized: "Safe stays at \(shown) here, about what this display can hold across the whole screen.",
                          bundle: b, locale: l,
                          comment: "Panel ▸ Display card: Safe on an HDR external display; the argument is a multiplier such as ×1.40")
        }
    }

    /// The Studio Display XDR case: its normal maximum already reaches the Safe level.
    public static func addsNothing(in language: CopyLanguage = .app) -> String {
        String(localized: "Safe adds no extra brightness on this display, because its normal maximum already reaches the level it can hold across the whole screen.",
               bundle: language.bundle, locale: language.locale,
               comment: "Panel ▸ Display card and Settings ▸ Displays: Safe on a display whose normal maximum already reaches it")
    }
}
