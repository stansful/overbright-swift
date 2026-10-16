// OverbrightOnboarding/Model/FindItShortcut.swift — the key-cap rows of Welcome step 4 (DESIGN.md §8: "key caps of the
// live Turn on or off, Back to Standard and Dim Below Minimum On or Off shortcuts in the current keyboard layout (rows
// without a registered shortcut are left out)"; §16: key caps are never literal). The caps come from
// `ShortcutCenter.displayString(_:)`, the same code that draws the menu's key equivalents.
import OverbrightCore

/// One shortcut row of step 4.
struct FindItShortcut: Hashable, Identifiable {
    /// The shortcut.
    let id: ShortcutID
    /// Its live key caps ("⌃⌥⌘B" on a US layout).
    let keys: String

    /// The rows of the shortcuts `WelcomePlan.shortcuts` names that are registered now, in that order.
    static func rows(_ center: any ShortcutCenter) -> [FindItShortcut] {
        WelcomePlan.shortcuts.compactMap { id in
            center.displayString(id).map { FindItShortcut(id: id, keys: $0) }
        }
    }
}
