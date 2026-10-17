// OverbrightDesign/Copy/ChipCopy.swift — the table of DESIGN.md §12.2: every per-display `LimitReason` → chip text,
// glyph, colour, popover sentence and actions. Global reasons (a user pause, S1/S2 conflicts, Focus, heat that stops,
// Low Power, battery, the schedule) and states that show no chip (off, shielded) map to nil.
import Foundation
import OverbrightCore
import OverbrightPolicy

/// The chips of DESIGN.md §12.2, one per reason.
nonisolated enum ChipCopy {
    /// Whether `reason` ever shows as a chip (per-display, not off or shielded).
    static func hasChip(_ reason: LimitReason) -> Bool {
        switch reason {
        case .masterOff, .shielded: false
        case let .conflict(app): app.severity == .conditional
        default: !reason.isGlobal
        }
    }

    /// The chip of `reason`, nil when it shows none.
    static func chip(for reason: LimitReason, failedTries: Int, context: ChipContext) -> ChipModel? {
        guard hasChip(reason) else { return nil }
        let language = context.language
        let (b, l) = (language.bundle, language.locale)
        func chip(_ symbol: OverbrightSymbol, _ color: SemanticColor, _ text: String, _ explanation: String,
                  _ actions: [FixAction] = [], label: String? = nil) -> ChipModel {
            ChipModel(symbol: symbol, color: color, text: text, explanation: explanation, accessibilityLabel: label ?? text,
                      showsProgress: false, actions: actions, helpAnchor: nil)
        }
        switch reason {
        case .waitingForHeadroom:
            return ChipModel.preparing(in: language)
        case .tripped(.headroomNeverArrived):
            return ChipModel.noExtraRange(failedTries: failedTries, context: context)
        case .boostNotEnabled:
            return chip(.sunMax, .neutral,
                        String(localized: "Extra brightness off", bundle: b, locale: l,
                               comment: "Panel ▸ Display card: status chip, extra brightness is turned off for this display"),
                        String(localized: "Extra brightness is off for this display. Dimming still works.", bundle: b, locale: l,
                               comment: "Panel ▸ Display card: popover of the Extra brightness off chip"), [.turnOn])
        case let .notSupported(verdict):
            let words = VerdictText.make(verdict, advisories: [], lastGrant: nil, capMode: .safe, in: language)
            return chip(.display, .neutral, words.badge, words.sentence, words.fix.map { [$0] } ?? [])
        case .headroom:
            let explanation = context.allowedGain.map { gain in
                let shown = CopyFormat.multiplier(gain, in: language)
                return String(localized: "macOS allows \(shown) right now. It lowers the extra range when the surroundings are bright, the display is warm or the battery is low.",
                              bundle: b, locale: l, comment: "Panel ▸ Display card: popover of Limited by macOS; the argument is a multiplier such as ×1.55")
            } ?? String(localized: "macOS allows less extra range right now. It lowers the extra range when the surroundings are bright, the display is warm or the battery is low.",
                        bundle: b, locale: l, comment: "Panel ▸ Display card: popover of Limited by macOS when the allowed gain is unknown")
            return chip(.sunMin, .info, limitedByMacOS(in: language), explanation)
        case .hdrSuppressedByMacOS:
            return chip(.sunMin, .info, limitedByMacOS(in: language),
                        String(localized: "macOS is limiting HDR right now.", bundle: b, locale: l,
                               comment: "Panel ▸ Display card: popover of Limited by macOS while macOS suppresses HDR"))
        case .nearFullBrightnessOnly:
            return chip(.sunMin, .info,
                        String(localized: "Below full brightness", bundle: b, locale: l,
                               comment: "Panel ▸ Display card: status chip, the display brightness is below full so extra brightness fades"),
                        String(localized: "Extra brightness fades out as you lower the display brightness. Turn the brightness up for more.",
                               bundle: b, locale: l, comment: "Panel ▸ Display card: popover of Below full brightness"), [.changeSetting])
        case .safeLimit:
            let first = context.safeLimit?.sentence(in: language)
                ?? String(localized: "Safe stays at the level this display can hold across the whole screen.", bundle: b, locale: l,
                          comment: "Panel ▸ Display card: popover of the Safe limit chip when the display’s class is unknown")
            return chip(.lockFill, .info,
                        String(localized: "Safe limit", bundle: b, locale: l, comment: "Panel ▸ Display card: status chip, the Safe ceiling binds"),
                        CopyFormat.sentences(first, choosePeakForMore(in: language), in: language), [.choosePeak])
        case .oledLimit:
            let gain = CopyFormat.roughNumber(GainCeiling.safeGainOLED, in: language)
            let first = String(localized: "Extra brightness stays at \(gain) times on OLED displays to protect the panel.",
                               bundle: b, locale: l, comment: "Panel ▸ Display card: popover of OLED limit; the argument is a multiplier such as 1.3")
            return chip(.lockFill, .info,
                        String(localized: "OLED limit", bundle: b, locale: l, comment: "Panel ▸ Display card: status chip, the OLED Safe ceiling binds"),
                        CopyFormat.sentences(first, choosePeakForMore(in: language), in: language), [.choosePeak])
        case .thermalSerious:
            let gain = CopyFormat.roughNumber(GainCeiling.thermalSeriousGain, in: language)
            return chip(.thermometerMedium, .warning,
                        String(localized: "Limited by heat", bundle: b, locale: l, comment: "Panel ▸ Display card: status chip, the Mac is warm"),
                        String(localized: "Your Mac is warm, so extra brightness stays at \(gain) times until it cools down.",
                               bundle: b, locale: l, comment: "Panel ▸ Display card: popover of Limited by heat; the argument is a multiplier such as 1.2"))
        case .fullScreenVideo:
            return chip(.playRectangleFill, .neutral, pausedVideo(in: language),
                        String(localized: "Extra brightness pauses while an app plays video full screen on this display.",
                               bundle: b, locale: l, comment: "Panel ▸ Display card: popover of Paused: video"), [.changeRules])
        case .fullScreenApp:
            return chip(.playRectangleFill, .neutral, pausedFullScreen(in: language),
                        String(localized: "Extra brightness pauses while an app is full screen on this display.",
                               bundle: b, locale: l, comment: "Panel ▸ Display card: popover of Paused: full screen"), [.changeRules])
        case let .pausedApp(bundleID):
            let name = (context.appName ?? bundleID).overbrightIsolated
            let text = pausedApp(name, in: language)
            return chip(.pauseFill, .neutral, text,
                        String(localized: "Extra brightness pauses while \(name) is in front on this display.", bundle: b, locale: l,
                               comment: "Panel ▸ Display card: popover of Paused: ‹App›; the argument is the app’s name"),
                        [.editApps], label: text)
        case .game:
            return chip(.gameControllerFill, .neutral, pausedGame(in: language),
                        String(localized: "Extra brightness pauses while a game is in front on this display.", bundle: b, locale: l,
                               comment: "Panel ▸ Display card: popover of Paused: game"), [.changeRules])
        case .oledIdle:
            let idle = CopyFormat.spokenDuration(minutes: context.oledIdleMinutes, in: language)
            return chip(.zzz, .neutral,
                        String(localized: "Paused: idle", bundle: b, locale: l, comment: "Panel ▸ Display card: status chip, an OLED display idles"),
                        String(localized: "Extra brightness pauses after \(idle) without input on OLED displays. Move the pointer or press a key to continue.",
                               bundle: b, locale: l, comment: "Panel ▸ Display card: popover of Paused: idle; the argument is a duration such as 5 minutes"))
        case let .conflict(app):
            let name = app.displayName.overbrightIsolated
            return chip(.exclamationMarkCircleFill, .info,
                        String(localized: "\(name) may interfere", bundle: b, locale: l,
                               comment: "Panel ▸ Display card: status chip naming an app that may change display colors"),
                        String(localized: "\(name) can change display colors in some modes. If it does, Overbright stops on this display.",
                               bundle: b, locale: l, comment: "Panel ▸ Display card: popover of ‹App› may interfere"))
        case .tripped(.oscillation), .tripped(.repairBudgetExceeded):
            return chip(.exclamationMarkTriangleFill, .danger,
                        String(localized: "Stopped", bundle: b, locale: l, comment: "Panel ▸ Display card: status chip, Overbright stopped this display"),
                        String(localized: "Overbright stopped on this display to prevent flicker.", bundle: b, locale: l,
                               comment: "Panel ▸ Display card: popover of Stopped"), [.tryAgain])
        case let .tripped(.attributedDrift(app)):
            let name = app.displayName.overbrightIsolated
            return chip(.exclamationMarkTriangleFill, .danger,
                        String(localized: "Stopped: \(name)", bundle: b, locale: l,
                               comment: "Panel ▸ Display card: status chip, an app changed this display’s colors; the argument is its name"),
                        String(localized: "\(name) changed the colors of this display.", bundle: b, locale: l,
                               comment: "Panel ▸ Display card: popover of Stopped: ‹App›"),
                        [app.severity == .booster ? .useCompatibilityMode : .continueAnyway])   // S1: §7.2
        case .tripped(.foreignTableAtLaunch):
            return chip(.exclamationMarkTriangleFill, .danger,
                        String(localized: "Colors changed", bundle: b, locale: l,
                               comment: "Panel ▸ Display card: status chip, another app changed this display’s colors"),
                        String(localized: "Another app changed this display’s colors in a way Overbright can’t reset.", bundle: b, locale: l,
                               comment: "Panel ▸ Display card: popover of Colors changed"), [.openSystemSettings])
        default:
            return nil
        }
    }

    /// "Limited by macOS".
    static func limitedByMacOS(in language: CopyLanguage) -> String {
        String(localized: "Limited by macOS", bundle: language.bundle, locale: language.locale,
               comment: "Panel ▸ Display card: status chip, macOS allows less extra range now")
    }

    /// "Paused: video".
    static func pausedVideo(in language: CopyLanguage) -> String {
        String(localized: "Paused: video", bundle: language.bundle, locale: language.locale,
               comment: "Panel ▸ Display card: status chip, a full-screen video plays on this display")
    }

    /// "Paused: full screen".
    static func pausedFullScreen(in language: CopyLanguage) -> String {
        String(localized: "Paused: full screen", bundle: language.bundle, locale: language.locale,
               comment: "Panel ▸ Display card: status chip, an app is full screen on this display")
    }

    /// "Paused: game".
    static func pausedGame(in language: CopyLanguage) -> String {
        String(localized: "Paused: game", bundle: language.bundle, locale: language.locale,
               comment: "Panel ▸ Display card: status chip, a game is in front on this display")
    }

    /// "Paused: ‹App›" (`name` already isolated).
    static func pausedApp(_ name: String, in language: CopyLanguage) -> String {
        String(localized: "Paused: \(name)", bundle: language.bundle, locale: language.locale,
               comment: "Panel ▸ Display card: status chip, a listed app is in front on this display; the argument is its name")
    }

    private static func choosePeakForMore(in language: CopyLanguage) -> String {
        String(localized: "Choose Peak for more.", bundle: language.bundle, locale: language.locale,
               comment: "Panel ▸ Display card: ends the popover of the Safe and OLED limit chips")
    }
}

