// OverbrightDesign/Copy/HUDText.swift — the HUD's value or reason line. DESIGN.md §6, §12.9; ARCHITECTURE.md §3.5.
// Seam written by WP0a (ARCHITECTURE.md §10.0): the type and `make(_:status:)` are fixed; WP9 writes the copy.
// The HUD shows changes made through a shortcut, the Shortcuts app, a Focus or Back to Standard; "Preparing…" for a
// turn-on that takes a moment; a reason when a change is blocked or an automation stops, caps or resumes the boost.
// Never for changes in the panel, the menu or Settings, and never for full-screen, app or game pauses.
import Foundation
import OverbrightCore
import OverbrightPolicy

/// What the HUD shows for one change: a level value with its bar, or a reason line instead of the bar.
public nonisolated struct HUDText: Hashable, Sendable {
    /// The leading glyph.
    public var symbol: OverbrightSymbol
    /// The display name, shown only with two or more displays.
    public var displayName: String?
    /// The value in canonical units ("Bright room · ×1.29"), when the HUD shows a level.
    public var value: String?
    /// The reason line ("Off: timer ended"), when the HUD shows one instead of the bar.
    public var reason: String?
    /// The VoiceOver announcement ("Bright room, 1.29 times").
    public var announcement: String

    /// A HUD text.
    public init(symbol: OverbrightSymbol, displayName: String?, value: String?, reason: String?, announcement: String) {
        self.symbol = symbol; self.displayName = displayName; self.value = value; self.reason = reason
        self.announcement = announcement
    }

    /// The HUD for `change` against the engine's current `status`; nil when the HUD shows nothing for it.
    public static func make(_ change: LevelChange, status: BoostStatus) -> HUDText? {
        make(change, status: status, on: nil, in: .app)
    }

    /// The HUD for `change` shown on `display` (for a change to every display, the display under the pointer; nil:
    /// the first one), in `language`.
    public static func make(_ change: LevelChange, status: BoostStatus, on display: DisplayKey?,
                            in language: CopyLanguage) -> HUDText? {
        let target = change.display ?? display ?? status.displays.first?.key
        let shown = status.displays.first { $0.key == target }
        let name = status.displays.count >= 2 ? shown?.name : nil
        func reasonLine(_ symbol: OverbrightSymbol, _ line: String) -> HUDText {
            HUDText(symbol: symbol, displayName: name, value: nil, reason: line, announcement: line)
        }
        switch change.kind {
        case .level:
            guard showsLevel(from: change.source) else { return nil }
            return level(of: shown, isOn: status.isOn, displayName: name, in: language)
        case .preparing:
            guard showsRequest(from: change.source) else { return nil }
            return reasonLine(.hourglass, CommonNames.preparing(in: language))
        case let .blocked(reason):
            guard showsRequest(from: change.source), let line = line(for: reason, userCaused: true, in: language) else {
                return nil
            }
            return reasonLine(symbol(for: reason), line)
        case let .automationStopped(reason):
            guard let line = line(for: reason, userCaused: false, in: language) else { return nil }
            return reasonLine(symbol(for: reason), line)
        case .automationResumed:
            return reasonLine(.sunMaxFill, String(localized: "Extra brightness is back", bundle: language.bundle,
                                                  locale: language.locale, comment: "HUD: an automation no longer stops extra brightness"))
        case .timerEnded:
            return reasonLine(.sunMax, String(localized: "Off: timer ended", bundle: language.bundle, locale: language.locale,
                                              comment: "HUD: the auto-off timer turned Overbright off"))
        }
    }

    // MARK: Private

    /// Level changes show for shortcuts, the Shortcuts app and a Focus (Back to Standard arrives through them).
    private static func showsLevel(from source: ControlSource) -> Bool {
        switch source {
        case .shortcut, .intent, .focusFilter: true
        case .panel, .menu, .settings, .welcome, .statusItem, .launch, .automation: false
        }
    }

    /// Preparing and blocked show for a request from the icon, a shortcut, the Shortcuts app or a Focus.
    private static func showsRequest(from source: ControlSource) -> Bool {
        switch source {
        case .statusItem, .shortcut, .intent, .focusFilter: true
        case .panel, .menu, .settings, .welcome, .launch, .automation: false
        }
    }

    private static func level(of display: DisplayStatus?, isOn: Bool, displayName: String?,
                              in language: CopyLanguage) -> HUDText {
        let values = display.map { Readout.values(for: $0, isMasterOn: isOn) }
        let text = isOn ? (values.map { ValueText.make($0, in: language) } ?? ValueText.make(
            ReadoutValues(state: .standard, appliedGain: 1, requestedGain: nil, nits: nil, preset: nil, isEstimate: false,
                          dimPercent: nil), in: language))
            : ValueText(text: CommonNames.off(in: language), accessibilityText: CommonNames.off(in: language))
        let state = isOn ? values?.state ?? .standard : .off
        let symbol: OverbrightSymbol = switch state {
        case .boost: .sunMaxFill
        case .dim: .sunMin
        case .preparing: .hourglass
        case .off, .standard: .sunMax
        }
        let announcement = displayName.map { CopyFormat.spokenParts($0, text.accessibilityText, in: language) }
            ?? text.accessibilityText
        return HUDText(symbol: symbol, displayName: displayName, value: text.text, reason: nil, announcement: announcement)
    }

    private static func symbol(for reason: LimitReason) -> OverbrightSymbol {
        switch reason {
        case .thermalSerious, .thermalCritical: .thermometerMedium
        default: .pauseFill
        }
    }

    /// The reason line of DESIGN.md §12.9; per-display reasons a user asked for repeat their chip. Nil for reasons
    /// the HUD never shows (off, shielded, and the full-screen, app and game pauses the user caused, which an
    /// automation must not announce).
    private static func line(for reason: LimitReason, userCaused: Bool, in language: CopyLanguage) -> String? {
        let (b, l) = (language.bundle, language.locale)
        switch reason {
        case let .userPaused(until):
            let time = CopyFormat.time(until, in: language)
            return String(localized: "Paused until \(time)", bundle: b, locale: l,
                          comment: "HUD: Overbright is paused; the argument is a time of day")
        case .focusOff:
            return String(localized: "Off for this Focus", bundle: b, locale: l,
                          comment: "HUD: the current Focus turned extra brightness off; “Focus” is macOS’s own name")
        case let .battery(_, threshold):
            let percent = CopyFormat.percent(threshold, in: language)
            return String(localized: "Paused: battery below \(percent)", bundle: b, locale: l,
                          comment: "HUD: paused on battery below the threshold; the argument is a percentage such as 20%")
        case .onBattery:
            return String(localized: "Paused: on battery", bundle: b, locale: l, comment: "HUD: paused on battery")
        case .lowPowerMode:
            return String(localized: "Paused: Low Power Mode", bundle: b, locale: l,
                          comment: "HUD: paused in Low Power Mode; “Low Power Mode” is macOS’s own name")
        case .thermalCritical:
            return String(localized: "Paused: Mac is hot", bundle: b, locale: l, comment: "HUD: paused because the Mac is hot")
        case .thermalSerious:
            return String(localized: "Limited: Mac is warm", bundle: b, locale: l,
                          comment: "HUD: extra brightness is limited because the Mac is warm")
        case .outsideSchedule:
            return String(localized: "Paused: outside set hours", bundle: b, locale: l,
                          comment: "HUD: extra brightness is outside the hours it is allowed")
        case .fullScreenVideo, .fullScreenApp, .pausedApp, .game, .oledIdle:
            guard userCaused else { return nil }
            return ChipCopy.chip(for: reason, failedTries: 0, context: ChipContext(language: language))?.text
        case .masterOff, .shielded:
            return nil
        default:
            return ChipCopy.chip(for: reason, failedTries: 0, context: ChipContext(language: language))?.text
        }
    }
}
