// OverbrightSettingsUI/Components/KeyComboFormatter.swift — what a key press means to the shortcut recorder
// (DESIGN.md §7.6: Esc cancels, Delete clears). Ported from Cranny's KeyComboFormatter (the owner's MIT code); the key
// caps themselves come from Core's `KeyCombo.keyCaps(in:)`, the same function the menu and `displayString` use. The
// rules of what may be a global shortcut are pure and tested: it needs ⌘, ⌃ or ⌥ (⇧ alone is typing), except for
// function keys.
import AppKit
import Carbon
import Foundation
import OverbrightCore

/// The recorder's reading of key presses.
enum KeyComboFormatter {
    /// What a key press means to the recorder.
    enum Outcome: Equatable {
        /// A shortcut to store.
        case combo(KeyCombo)
        /// Esc without modifiers: stop recording, keep the shortcut.
        case cancel
        /// Delete or Forward Delete without modifiers: turn the shortcut off.
        case clear
        /// A plain or ⇧-only key that is not a function key.
        case needsModifier
    }

    /// The recorder's decision for `keyCode` with `modifiers`.
    static func outcome(keyCode: UInt16, modifiers: KeyCombo.Modifiers) -> Outcome {
        let hasCommandKey = !modifiers.intersection([.command, .control, .option]).isEmpty
        if !hasCommandKey && modifiers.isEmpty {
            if keyCode == UInt16(kVK_Escape) { return .cancel }
            if keyCode == UInt16(kVK_Delete) || keyCode == UInt16(kVK_ForwardDelete) { return .clear }
        }
        if !hasCommandKey && KeyCombo.functionKeys[keyCode] == nil { return .needsModifier }
        return .combo(KeyCombo(keyCode: keyCode, modifiers: modifiers))
    }

    /// `NSEvent.ModifierFlags` → `KeyCombo.Modifiers` (Caps Lock and Fn ignored).
    static func modifiers(_ flags: NSEvent.ModifierFlags) -> KeyCombo.Modifiers {
        var modifiers: KeyCombo.Modifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        return modifiers
    }

    /// The key caps of `combo` in the keyboard layout key caps are drawn in ("⌃⌥⌘B").
    static func keyCaps(_ combo: KeyCombo) -> String {
        combo.keyCaps(in: .forDisplay(), spaceName: spaceName)
    }

    /// The space bar's name in key caps.
    static var spaceName: String {
        String(localized: "Space", bundle: .module,
               comment: "Settings ▸ Shortcuts: name of the space bar in a shortcut’s key caps")
    }
}
