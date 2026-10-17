// OverbrightPanelUI/Panel/FooterChips.swift — the footer's three guard chips: what each shows (its SETTING, never a
// live value, except the timer counting down) and its menu, which edits the Automations keys directly. DESIGN.md §5.9
// (labels, menus, the 304-pt row and the glyph + value fallback), §12.5 (numbers through FormatStyle), §12.7
// (VoiceOver: the label is the chip's name, "Battery limit", "Auto-pause", "Timer", and the value its state, "Below
// 20 %", "On", "No timer", in every row style); ARCHITECTURE.md §3.8 (the keys and ranges).
import Foundation
import OverbrightCore
import OverbrightDesign

/// One footer chip: the full model, the compact fallback (glyph + value) and its menu.
public struct FooterChip {
    /// Which chip.
    public enum Kind: Hashable, CaseIterable, Sendable {
        /// Battery rule.
        case battery
        /// Auto-pause rules.
        case autoPause
        /// The auto-off timer.
        case timer
    }

    /// Which chip.
    public let kind: Kind
    /// Glyph and the setting's words.
    public let model: GuardChipModel
    /// Glyph and the value alone, used when the row does not fit (DESIGN.md §5.9).
    public let compact: GuardChipModel
    /// The chip's menu.
    public let menu: [GuardChipMenuItem]

    /// A chip from its full and compact models.
    public init(kind: Kind, model: GuardChipModel, compact: GuardChipModel, menu: [GuardChipMenuItem]) {
        self.kind = kind; self.model = model; self.compact = compact; self.menu = menu
    }

    /// A chip named `name` (VoiceOver's label) whose state is `state` (VoiceOver's value), showing `text`, or
    /// `compactText` beside the glyph when the row does not fit.
    init(kind: Kind, name: String, state: String, symbol: OverbrightSymbol, text: String, compactText: String,
         menu: [GuardChipMenuItem]) {
        self.init(kind: kind,
                  model: GuardChipModel(symbol: symbol, text: text, accessibilityLabel: name, compactText: compactText,
                                        accessibilityValue: state),
                  compact: GuardChipModel(symbol: symbol, text: compactText, accessibilityLabel: name, compactText: nil,
                                          accessibilityValue: state),
                  menu: menu)
    }
}

/// Builds the footer chips from the settings.
public enum FooterChips {
    /// The battery levels the chip offers (Settings offers 5–95 %).
    public static let batteryLevels = [10, 20, 30, 50]
    /// The timer durations the chip offers, in minutes (Settings offers 5 minutes to 2 hours).
    public static let timerMinutes = [15, 30, 60, 120]

    /// The chips in order: Battery (only on a Mac with a battery), Auto-pause, Timer. `autoOffAt` is the engine's
    /// running deadline and `now` the wall clock (the timer counts down while it runs); `editApps` opens the
    /// paused-apps list in Settings.
    public static func chips(settings: SettingsStore, hasBattery: Bool, autoOffAt: Date?, now: Date,
                             editApps: @escaping @MainActor () -> Void) -> [FooterChip] {
        (hasBattery ? [battery(settings)] : [])
            + [autoPause(settings, editApps: editApps), timer(settings, autoOffAt: autoOffAt, now: now)]
    }

    // MARK: Battery

    static func battery(_ settings: SettingsStore) -> FooterChip {
        let rule = settings[AutomationSettings.batteryGuard]
        let threshold = settings[AutomationSettings.batteryThreshold]
        let percent = FooterText.percent(threshold)
        let text: String = switch rule {
        case .belowThreshold: FooterText.below(percent)
        case .onlyOnAdapter: FooterText.adapterOnly
        case .off: FooterText.anyCharge
        }
        let symbol: OverbrightSymbol = switch rule {
        case .belowThreshold: .battery25Percent
        case .onlyOnAdapter: .powerPlugFill
        case .off: .battery100PercentBolt
        }
        var levels = batteryLevels
        if !levels.contains(threshold) { levels = (levels + [threshold]).sorted() }
        let menu: [GuardChipMenuItem] = [
            .item(title: FooterText.pauseBelowALevel, isChecked: rule == .belowThreshold) {
                settings[AutomationSettings.batteryGuard] = .belowThreshold
            },
            .item(title: FooterText.pauseOnBattery, isChecked: rule == .onlyOnAdapter) {
                settings[AutomationSettings.batteryGuard] = .onlyOnAdapter
            },
            .item(title: FooterText.keepBoosting, isChecked: rule == .off) {
                settings[AutomationSettings.batteryGuard] = .off
            },
            .separator,
            .submenu(title: FooterText.batteryLevel, items: levels.map { level in
                .item(title: FooterText.percent(level), isChecked: level == threshold) {
                    settings[AutomationSettings.batteryThreshold] = level
                    settings[AutomationSettings.batteryGuard] = .belowThreshold
                }
            }),
        ]
        return FooterChip(kind: .battery, name: FooterText.batteryLimit, state: text, symbol: symbol, text: text,
                          compactText: rule == .belowThreshold ? percent : "", menu: menu)
    }

    // MARK: Auto-pause

    static func autoPause(_ settings: SettingsStore, editApps: @escaping @MainActor () -> Void) -> FooterChip {
        let video = settings[AutomationSettings.pauseForFullScreenVideo]
        let everyApp = settings[AutomationSettings.pauseForAllFullScreen]
        let listed = settings[AutomationSettings.pauseForListedApps]
        let isOn = video || everyApp || listed
        let text = isOn ? FooterText.autoPause : FooterText.autoPauseOff
        let menu: [GuardChipMenuItem] = [
            .item(title: FooterText.pauseForFullScreenVideo, isChecked: video) {
                settings[AutomationSettings.pauseForFullScreenVideo] = !video
            },
            .item(title: FooterText.pauseForEveryFullScreenApp, isChecked: everyApp) {
                settings[AutomationSettings.pauseForAllFullScreen] = !everyApp
            },
            .item(title: FooterText.pauseForListedApps, isChecked: listed) {
                settings[AutomationSettings.pauseForListedApps] = !listed
            },
            .separator,
            .item(title: FooterText.editApps, isChecked: false, perform: editApps),
        ]
        return FooterChip(kind: .autoPause, name: FooterText.autoPause, state: isOn ? FooterText.on : FooterText.off,
                          symbol: .playRectangleFill, text: text, compactText: isOn ? "" : FooterText.off, menu: menu)
    }

    // MARK: Timer

    static func timer(_ settings: SettingsStore, autoOffAt: Date?, now: Date) -> FooterChip {
        let minutes = settings[AutomationSettings.autoOffMinutes]
        let text: String
        let value: String
        if let autoOffAt {
            value = FooterText.duration(minutes: max(Int((autoOffAt.timeIntervalSince(now) / 60).rounded(.up)), 1))
            text = FooterText.offIn(value)
        } else if let minutes {
            value = FooterText.duration(minutes: minutes)
            text = FooterText.offAfter(value)
        } else {
            value = ""
            text = FooterText.noTimer
        }
        var choices: [Int?] = [nil] + timerMinutes.map(Optional.some)
        if let minutes, !timerMinutes.contains(minutes) {
            choices = [nil] + (timerMinutes + [minutes]).sorted().map(Optional.some)
        }
        let menu: [GuardChipMenuItem] = [
            .submenu(title: FooterText.turnOffAfter, items: choices.map { choice in
                .item(title: choice.map { FooterText.menuDuration(minutes: $0) } ?? FooterText.never,
                      isChecked: choice == minutes) {
                    settings[AutomationSettings.autoOffMinutes] = choice
                }
            }),
        ]
        return FooterChip(kind: .timer, name: FooterText.timerLabel, state: text, symbol: .timer, text: text,
                          compactText: value, menu: menu)
    }
}
