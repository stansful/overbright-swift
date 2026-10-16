// OverbrightAppShell/App/ShortcutActions.swift — what each global shortcut does. ARCHITECTURE.md §3.7, §10.15
// (the composition root hands `HotKeyCenter.onPress` the engine's calls; HotKeys knows no actions), D17; DESIGN.md §7.6.
// Every press is `.shortcut`, so the HUD shows the change (DESIGN.md §6).
import OverbrightCore
import os

private let log = Log.logger(.hotKeys)

/// The engine and Fill Light calls behind the shortcuts.
enum ShortcutActions {
    /// Runs the action of `shortcut`.
    static func perform(_ shortcut: ShortcutID, boost: any BoostControl, fillLight: any FillLightControl) {
        switch shortcut {
        case .toggle: boost.toggle(source: .shortcut)
        case .brighter: boost.step(.brighter, source: .shortcut)
        case .lessBright: boost.step(.lessBright, source: .shortcut)
        case .max: boost.setExtraBrightness(.preset(.max), for: nil, source: .shortcut)
        case .standard: boost.returnToStandard(source: .shortcut)
        case .dimToggle: boost.toggleDim(source: .shortcut)
        case .fillLight: fillLight.setOn(!fillLight.isOn, source: .shortcut)
        default: log.error("no action for shortcut \(shortcut.rawValue, privacy: .public)")
        }
    }
}
