// OverbrightSettingsUI/Components/SystemShortcut.swift — one enabled macOS shortcut (DESIGN.md §7.6: "macOS uses this
// for ‹name of the system shortcut›"). Ported from Cranny's SystemShortcuts.swift (the owner's MIT code).
import OverbrightCore

/// One macOS shortcut that is turned on.
nonisolated struct SystemShortcut: Equatable, Sendable {
    /// The `com.apple.symbolichotkeys` identifier.
    let id: Int
    /// The key position.
    let keyCode: UInt16
    /// The modifiers held.
    let modifiers: KeyCombo.Modifiers

    /// Whether `combo` is this shortcut's combination.
    func matches(_ combo: KeyCombo) -> Bool { combo.keyCode == keyCode && combo.modifiers == modifiers }
}
