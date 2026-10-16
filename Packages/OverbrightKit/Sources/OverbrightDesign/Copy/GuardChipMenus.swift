// OverbrightDesign/Copy/GuardChipMenus.swift — the menus of the footer guard chips. DESIGN.md §5.9 (title case, AppKit
// chrome). The panel supplies what each row does; the words and the order live here with the names they use.
import Foundation
import OverbrightCore

/// The rows of the Battery, Auto-pause and Timer chips' menus.
public enum GuardChipMenus {
    /// The battery levels offered in the menu (Settings offers 5–95 %).
    public static let batteryLevels = [10, 20, 30, 50]
    /// The timer durations offered in the menu, in minutes (Settings offers 5 minutes to 2 hours).
    public static let timerMinutes = [15, 30, 60, 120]

    /// ✓ Pause Below a Level · Pause on Battery · Keep Boosting · ─ · Battery Level ▸ 10% · 20% · 30% · 50% (plus the
    /// current level with a checkmark when it is not one of these).
    public static func battery(current: BatteryGuard, threshold: Int, setGuard: @escaping @MainActor (BatteryGuard) -> Void,
                               setThreshold: @escaping @MainActor (Int) -> Void,
                               in language: CopyLanguage = .app) -> [GuardChipMenuItem] {
        let guards: [GuardChipMenuItem] = BatteryGuard.allCases.map { option in
            .item(title: option.menuTitle(in: language), isChecked: option == current, perform: { setGuard(option) })
        }
        let levels = (batteryLevels.contains(threshold) ? batteryLevels : (batteryLevels + [threshold]).sorted())
            .map { level -> GuardChipMenuItem in
                .item(title: CopyFormat.percent(level, in: language), isChecked: level == threshold,
                      perform: { setThreshold(level) })
            }
        let title = String(localized: "Battery Level", bundle: language.bundle, locale: language.locale,
                           comment: "Panel ▸ Footer chip: Battery chip submenu of battery levels (title case)")
        return guards + [.separator, .submenu(title: title, items: levels)]
    }

    /// ✓ Pause for Full-Screen Video · Pause for Every Full-Screen App · ✓ Pause for Apps in the List · ─ · Edit Apps…
    public static func autoPause(video: Bool, everyFullScreen: Bool, listedApps: Bool,
                                 toggleVideo: @escaping @MainActor () -> Void,
                                 toggleEveryFullScreen: @escaping @MainActor () -> Void,
                                 toggleListedApps: @escaping @MainActor () -> Void,
                                 editApps: @escaping @MainActor () -> Void,
                                 in language: CopyLanguage = .app) -> [GuardChipMenuItem] {
        let (b, l) = (language.bundle, language.locale)
        return [
            .item(title: String(localized: "Pause for Full-Screen Video", bundle: b, locale: l,
                                comment: "Panel ▸ Footer chip: Auto-pause chip menu item (title case)"),
                  isChecked: video, perform: toggleVideo),
            .item(title: String(localized: "Pause for Every Full-Screen App", bundle: b, locale: l,
                                comment: "Panel ▸ Footer chip: Auto-pause chip menu item (title case)"),
                  isChecked: everyFullScreen, perform: toggleEveryFullScreen),
            .item(title: String(localized: "Pause for Apps in the List", bundle: b, locale: l,
                                comment: "Panel ▸ Footer chip: Auto-pause chip menu item, the app list’s master switch (title case)"),
                  isChecked: listedApps, perform: toggleListedApps),
            .separator,
            .item(title: FixAction.editApps.menuTitle(in: language), isChecked: false, perform: editApps),
        ]
    }

    /// Turn Off After ▸ Never · 15 Minutes · 30 Minutes · 1 Hour · 2 Hours (plus the current value when it is another
    /// one). `minutes` nil is Never.
    public static func timer(minutes: Int?, set: @escaping @MainActor (Int?) -> Void,
                             in language: CopyLanguage = .app) -> [GuardChipMenuItem] {
        let (b, l) = (language.bundle, language.locale)
        let never = String(localized: "Never", bundle: b, locale: l,
                           comment: "Panel ▸ Footer chip: Timer chip menu item, no auto-off timer (title case)")
        var choices = timerMinutes
        if let minutes, !choices.contains(minutes) { choices = (choices + [minutes]).sorted() }
        let rows: [GuardChipMenuItem] = [.item(title: never, isChecked: minutes == nil, perform: { set(nil) })]
            + choices.map { value in
                .item(title: timerTitle(minutes: value, in: language), isChecked: value == minutes, perform: { set(value) })
            }
        let title = String(localized: "Turn Off After", bundle: b, locale: l,
                           comment: "Panel ▸ Footer chip: Timer chip submenu of auto-off durations (title case)")
        return [.submenu(title: title, items: rows)]
    }

    /// "15 Minutes" · "1 Hour" · "2 Hours" · "1 Hour, 30 Minutes": a timer duration as a menu row. Menus are title
    /// case (DESIGN.md §5.9, §12), which `Duration.UnitsFormatStyle` does not write, so the units are plural keys and
    /// every language writes its own forms and capitalization.
    public static func timerTitle(minutes: Int, in language: CopyLanguage = .app) -> String {
        let (b, l) = (language.bundle, language.locale)
        let total = max(minutes, 0)
        let hours = total / 60, rest = total % 60
        func hourText() -> String {
            String(localized: "\(hours) Hours", bundle: b, locale: l,
                   comment: "Panel ▸ Footer chip: Timer chip menu item, a duration in whole hours such as 1 Hour or 2 Hours (title case)")
        }
        func minuteText() -> String {
            String(localized: "\(rest) Minutes", bundle: b, locale: l,
                   comment: "Panel ▸ Footer chip: Timer chip menu item, a duration in minutes such as 15 Minutes (title case)")
        }
        if hours == 0 { return minuteText() }
        if rest == 0 { return hourText() }
        return CopyFormat.spokenParts(hourText(), minuteText(), in: language)
    }
}
