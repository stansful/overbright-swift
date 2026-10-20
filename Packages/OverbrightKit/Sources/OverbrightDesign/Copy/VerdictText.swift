// OverbrightDesign/Copy/VerdictText.swift — a display's verdict in words. DESIGN.md §12.1; ARCHITECTURE.md D8.
// Seam written by WP0a (ARCHITECTURE.md §10.0): the type and `make(_:advisories:lastGrant:)` are fixed; WP9 writes
// the copy. A supported verdict quotes the display's current limit (Safe by default) and, once Overbright has seen
// one, the largest grant macOS gave; the potential-derived figure never appears here.
import Foundation
import OverbrightCore

/// The badge, sentence, advisory lines and fix of a display verdict (Settings ▸ Displays, Welcome, "Why?" rows).
public nonisolated struct VerdictText: Hashable, Sendable {
    /// The badge ("Supported", "HDR is off").
    public var badge: String
    /// The verdict sentence.
    public var sentence: String
    /// One line per advisory, in order.
    public var advisories: [String]
    /// The fix button's title ("Open System Settings", "Choose Peak…"), if the verdict has one.
    public var fixTitle: String?
    /// What the fix does.
    public var fix: FixAction?

    /// A verdict text.
    public init(badge: String, sentence: String, advisories: [String], fixTitle: String?) {
        self.init(badge: badge, sentence: sentence, advisories: advisories, fix: nil, fixTitle: fixTitle)
    }

    /// A verdict text with its fix.
    public init(badge: String, sentence: String, advisories: [String], fix: FixAction?, fixTitle: String?) {
        self.badge = badge; self.sentence = sentence; self.advisories = advisories; self.fix = fix
        self.fixTitle = fixTitle
    }

    /// The words for `verdict`. `lastGrant` is the largest grant macOS gave this display, once one was seen; the
    /// potential-derived figure never appears here (D8).
    public static func make(_ verdict: DisplayVerdict, advisories: [Advisory], lastGrant: Double?) -> VerdictText {
        make(verdict, advisories: advisories, lastGrant: lastGrant, capMode: .safe, in: .app)
    }

    /// The words for `verdict` with the display's chosen ceiling (`capMode`), in `language`. `oledIdleMinutes` is the
    /// OLED idle pause of Settings ▸ Automations.
    public static func make(_ verdict: DisplayVerdict, advisories: [Advisory], lastGrant: Double?, capMode: CapMode,
                            oledIdleMinutes: Int = 5, in language: CopyLanguage) -> VerdictText {
        let (b, l) = (language.bundle, language.locale)
        let lines = advisories.map { line(for: $0, oledIdleMinutes: oledIdleMinutes, in: language) }
        let unsupported = String(localized: "Not supported", bundle: b, locale: l,
                                 comment: "Verdict badge: the display cannot be adjusted or has no extra range")
        let stillDims = String(localized: "You can still dim it below the minimum.", bundle: b, locale: l,
                               comment: "Verdict: ends the sentence of a display that cannot boost but can dim")
        func text(_ badge: String, _ sentence: String, _ fix: FixAction? = nil) -> VerdictText {
            VerdictText(badge: badge, sentence: sentence, advisories: lines, fix: fix, fixTitle: fix?.title(in: language))
        }
        switch verdict {
        case let .supported(safeGain, peakGain):
            let badge = String(localized: "Supported", bundle: b, locale: l, comment: "Verdict badge: the display can show extra brightness")
            let (sentence, fix) = supported(safeGain: safeGain, peakGain: peakGain, capMode: capMode,
                                            grant: lastGrant.map { grant(of: $0, in: language) }, in: language)
            return text(badge, sentence, fix)
        case .noGainAtFullBrightness:
            let tenPercent = CopyFormat.percent(10, in: language)
            return text(String(localized: "Little gain", bundle: b, locale: l, comment: "Verdict badge: Peak adds less than 10 % at full brightness"),
                        String(localized: "At full brightness this display gains less than \(tenPercent). Raising the display brightness gives the same result.",
                               bundle: b, locale: l, comment: "Verdict: a display that gains little; the argument is a percentage such as 10%"))
        case .panelFactsUnknown:
            let sentence = String(localized: "Overbright can’t tell how much brighter this display can get, so it adds no extra brightness.",
                                  bundle: b, locale: l,
                                  comment: "Verdict: Overbright does not know the display’s peak or its normal maximum brightness, so it adds none; followed by “You can still dim it below the minimum.”")
            return text(String(localized: "Range unknown", bundle: b, locale: l,
                               comment: "Verdict badge: Overbright cannot tell how much extra brightness the display has"),
                        CopyFormat.sentences(sentence, stillDims, in: language))
        case let .presetLimits(presetPeak, panelPeak):
            let stops = Int(presetPeak.rounded()), example = Int(panelPeak.rounded())
            let first = String(localized: "The current preset stops at about \(stops) nits.", bundle: b, locale: l,
                               comment: "Verdict: the display preset limits HDR; the argument is the preset’s peak in nits")
            let second = String(localized: "Choose a preset with a higher peak, such as \(example) nits, in Displays settings.",
                                bundle: b, locale: l, comment: "Verdict: follows “The current preset stops at…”; the argument is the panel’s peak in nits")
            return text(String(localized: "Limited by preset", bundle: b, locale: l, comment: "Verdict badge: the display preset limits HDR"),
                        CopyFormat.sentences(first, second, in: language), .openSystemSettings)
        case .turnOnHDR:
            let sentence = String(localized: "Turn on High Dynamic Range for this display in Displays settings to use extra brightness. This changes how everyday content looks on some displays. You can turn it off again at any time.",
                                  bundle: b, locale: l, comment: "Verdict: an HDR display with HDR off; “High Dynamic Range” and “Displays” are macOS’s own names")
            return text(String(localized: "HDR is off", bundle: b, locale: l, comment: "Verdict badge: HDR is off for this display"),
                        CopyFormat.sentences(sentence, stillDims, in: language), .openSystemSettings)
        case .switchPreset:
            let sentence = String(localized: "This preset doesn’t allow extra brightness. Choose a preset with a higher peak in Displays settings.",
                                  bundle: b, locale: l, comment: "Verdict: the display preset allows no extra brightness")
            return text(String(localized: "No HDR in this preset", bundle: b, locale: l, comment: "Verdict badge: the display preset has no HDR"),
                        CopyFormat.sentences(sentence, stillDims, in: language), .openSystemSettings)
        case .referencePreset:
            return text(String(localized: "Reference mode", bundle: b, locale: l, comment: "Verdict badge: a reference preset is active"),
                        String(localized: "A reference preset is active. Overbright leaves reference modes as they are.",
                               bundle: b, locale: l, comment: "Verdict: a reference preset is active"), .openSystemSettings)
        case .lcdClass:
            let sentence = String(localized: "This display has no extra brightness range.", bundle: b, locale: l,
                                  comment: "Verdict: a display without extra range")
            return text(unsupported, CopyFormat.sentences(sentence, stillDims, in: language))
        case .notHDR:
            let sentence = String(localized: "This display doesn’t support HDR, so it has no extra range.", bundle: b, locale: l,
                                  comment: "Verdict: an SDR display")
            return text(unsupported, CopyFormat.sentences(sentence, stillDims, in: language))
        case .mirrored:
            return text(String(localized: "Mirrored", bundle: b, locale: l, comment: "Verdict badge: the display mirrors another one"),
                        String(localized: "This display mirrors another one, so Overbright can only dim it.", bundle: b, locale: l,
                               comment: "Verdict: a display that mirrors another one"))
        case .virtualDisplay:
            return text(unsupported, String(localized: "Sidecar and AirPlay displays can’t be adjusted.", bundle: b, locale: l,
                                            comment: "Verdict: a Sidecar or AirPlay display"))
        case .noGammaTable:
            return text(unsupported, String(localized: "macOS doesn’t let apps adjust this display.", bundle: b, locale: l,
                                            comment: "Verdict: a display without a color table"))
        case .checking:
            return text(String(localized: "Checking…", bundle: b, locale: l, comment: "Verdict badge: Overbright is still reading the display"),
                        String(localized: "Overbright is reading this display.", bundle: b, locale: l,
                               comment: "Verdict: Overbright is still reading the display"))
        }
    }

    /// The line of `advisory` (a second line under the verdict).
    public static func line(for advisory: Advisory, oledIdleMinutes: Int = 5, in language: CopyLanguage = .app) -> String {
        let (b, l) = (language.bundle, language.locale)
        switch advisory {
        case .oledCare:
            let idle = CopyFormat.spokenDuration(minutes: oledIdleMinutes, in: language)
            return String(localized: "OLED display: extra brightness stays lower and pauses after \(idle) without input.",
                          bundle: b, locale: l, comment: "Verdict advisory: OLED care; the argument is a duration such as 5 minutes")
        case .autoBrightnessInteracts:
            return String(localized: "Keep Automatically adjust brightness as it is while extra brightness is on. Changing it then can leave the picture wrong until you change the display preset.",
                          bundle: b, locale: l, comment: "Settings ▸ Displays: advisory on built-in XDR displays; “Automatically adjust brightness” is macOS’s own name")
        case .notCalibrated:
            return String(localized: "Not calibrated. Numbers are estimates, and Overbright uses a safe default.",
                          bundle: b, locale: l, comment: "Verdict advisory: the display has no valid calibration")
        }
    }

    // MARK: Private

    /// The sentence of a supported display: its ceiling, then the largest grant macOS gave once there is one (else,
    /// in Safe, that Peak can go further).
    private static func supported(safeGain: Double?, peakGain: Double, capMode: CapMode, grant: String?,
                                  in language: CopyLanguage) -> (String, FixAction?) {
        let (b, l) = (language.bundle, language.locale)
        let peak = CopyFormat.roughNumber(peakGain, in: language)
        let withPeak = String(localized: "With Peak, up to about \(peak)× brighter at full brightness, when macOS allows it.",
                              bundle: b, locale: l, comment: "Verdict: a supported display with Peak; the argument is a gain such as 2.6")
        guard let safeGain, safeGain >= 1.05 else {
            if capMode == .peak { return (CopyFormat.sentences(withPeak, grant ?? "", in: language), nil) }
            let sentence = CopyFormat.sentences(SafeLimitText.addsNothing(in: language), withPeak, in: language)
            return (CopyFormat.sentences(sentence, grant ?? "", in: language), .choosePeak)
        }
        if capMode == .peak { return (CopyFormat.sentences(withPeak, grant ?? "", in: language), nil) }
        let safe = CopyFormat.roughNumber(safeGain, in: language)
        let withSafe = String(localized: "With Safe, up to about \(safe)× brighter at full brightness.", bundle: b, locale: l,
                              comment: "Verdict: a supported display with Safe; the argument is a gain such as 1.7")
        let further = String(localized: "Peak can go further when macOS allows it.", bundle: b, locale: l,
                             comment: "Verdict: follows “With Safe, up to about 1.7× brighter…” until macOS has given a grant")
        return (CopyFormat.sentences(withSafe, grant ?? further, in: language), nil)
    }

    private static func grant(of gain: Double, in language: CopyLanguage) -> String {
        let shown = CopyFormat.multiplier(gain, in: language)
        return String(localized: "macOS allowed up to \(shown) on this display last time.", bundle: language.bundle,
                      locale: language.locale, comment: "Verdict: the largest gain macOS gave; the argument is a multiplier such as ×1.55")
    }
}
