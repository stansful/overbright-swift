// OverbrightDesign/Copy/GuardChipModel.swift — what one footer guard chip shows. DESIGN.md §5.9, §12.7.
// Seam written by WP0a (ARCHITECTURE.md §10.0); WP9 owns it. A footer chip shows its setting, never a live value
// (the timer's countdown excepted); when the three chips do not fit 292 pt, each drops to glyph + `compactText`.
import Foundation
import OverbrightCore

/// A footer chip (Battery, Auto-pause, Timer): its setting, never a live value.
public nonisolated struct GuardChipModel: Hashable, Sendable {
    /// The glyph.
    public var symbol: OverbrightSymbol
    /// The setting ("Below 20 %"), already localized.
    public var text: String
    /// The VoiceOver label ("Battery limit").
    public var accessibilityLabel: String
    /// The short value shown next to the glyph when the footer is too narrow ("20%"); nil shows the glyph alone.
    public var compactText: String?
    /// The VoiceOver value ("Below 20%").
    public var accessibilityValue: String?

    /// A footer chip.
    public init(symbol: OverbrightSymbol, text: String, accessibilityLabel: String) {
        self.symbol = symbol; self.text = text; self.accessibilityLabel = accessibilityLabel
    }

    /// A footer chip with its compact text and VoiceOver value.
    public init(symbol: OverbrightSymbol, text: String, accessibilityLabel: String, compactText: String?,
                accessibilityValue: String?) {
        self.init(symbol: symbol, text: text, accessibilityLabel: accessibilityLabel)
        self.compactText = compactText; self.accessibilityValue = accessibilityValue
    }

    /// The Battery chip: "Below 20%" / "Adapter only" / "Any charge".
    public static func battery(_ guard: BatteryGuard, threshold: Int, in language: CopyLanguage = .app) -> GuardChipModel {
        let (b, l) = (language.bundle, language.locale)
        let label = String(localized: "Battery limit", bundle: b, locale: l, comment: "VoiceOver: label of the Battery footer chip")
        let percent = CopyFormat.percent(threshold, in: language)
        let text: String
        var compact: String?
        switch `guard` {
        case .belowThreshold:
            text = String(localized: "Below \(percent)", bundle: b, locale: l,
                          comment: "Panel ▸ Footer chip: Battery chip, pause below a battery level; the argument is a percentage such as 20%")
            compact = percent
        case .onlyOnAdapter:
            text = String(localized: "Adapter only", bundle: b, locale: l,
                          comment: "Panel ▸ Footer chip: Battery chip, extra brightness only on the power adapter")
        case .off:
            text = String(localized: "Any charge", bundle: b, locale: l,
                          comment: "Panel ▸ Footer chip: Battery chip, extra brightness at any battery charge")
        }
        return GuardChipModel(symbol: .battery25Percent, text: text, accessibilityLabel: label, compactText: compact,
                              accessibilityValue: text)
    }

    /// The Auto-pause chip: "Auto-pause" while any rule is on, else "Auto-pause · Off".
    public static func autoPause(anyRuleOn: Bool, in language: CopyLanguage = .app) -> GuardChipModel {
        let name = String(localized: "Auto-pause", bundle: language.bundle, locale: language.locale,
                          comment: "Panel ▸ Footer chip: the Auto-pause chip (full-screen video, full-screen apps, listed apps)")
        let off = CommonNames.off(in: language)
        let state = anyRuleOn ? StatusSymbolState.on.accessibilityValue(in: language) : off
        return GuardChipModel(symbol: .playRectangleFill, text: anyRuleOn ? name : CopyFormat.parts(name, off, in: language),
                              accessibilityLabel: name, compactText: anyRuleOn ? nil : off, accessibilityValue: state)
    }

    /// The Timer chip: "No timer", "Off in 23 min" while counting down, "Off after 30 min" while Overbright is off.
    /// `minutes` is the setting (nil: Never); `remaining` the time left while it counts down.
    public static func timer(minutes: Int?, remaining: Duration?, in language: CopyLanguage = .app) -> GuardChipModel {
        let (b, l) = (language.bundle, language.locale)
        let label = String(localized: "Timer", bundle: b, locale: l, comment: "VoiceOver: label of the Timer footer chip")
        guard let minutes else {
            let none = String(localized: "No timer", bundle: b, locale: l, comment: "Panel ▸ Footer chip: Timer chip, no auto-off timer")
            return GuardChipModel(symbol: .timer, text: none, accessibilityLabel: label, compactText: nil, accessibilityValue: none)
        }
        if let remaining {
            let left = Int((Double(remaining.components.seconds) / 60).rounded(.up))
            let time = CopyFormat.duration(minutes: max(left, 1), in: language)
            let text = String(localized: "Off in \(time)", bundle: b, locale: l,
                              comment: "Panel ▸ Footer chip: Timer chip counting down; the argument is a duration such as 23 min")
            return GuardChipModel(symbol: .timer, text: text, accessibilityLabel: label, compactText: time, accessibilityValue: text)
        }
        let time = CopyFormat.duration(minutes: minutes, in: language)
        let text = String(localized: "Off after \(time)", bundle: b, locale: l,
                          comment: "Panel ▸ Footer chip: Timer chip while Overbright is off; the argument is the timer’s duration")
        return GuardChipModel(symbol: .timer, text: text, accessibilityLabel: label, compactText: time, accessibilityValue: text)
    }
}
