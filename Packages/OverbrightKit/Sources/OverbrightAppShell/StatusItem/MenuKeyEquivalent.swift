// OverbrightAppShell/StatusItem/MenuKeyEquivalent.swift — a global shortcut shown as a menu item's key equivalent, so
// the menu always tells the truth about the live binding: its key caps in the CURRENT keyboard layout, the new
// combination after a rebind, nothing when the shortcut is cleared or failed to register. DESIGN.md §4.3, §16;
// ARCHITECTURE.md §3.6 (`ShortcutCenter.displayString` is "the same code as the menu's live key equivalents").
// Ported idea from Cranny's MenuKeyEquivalent (the owner's MIT code), rebuilt on `displayString`. Named keys (Space,
// Return, Tab, Delete, Esc, the arrows, F1–F12) come from the combo's key code, never from their caps, whose names are
// localized ("Пробел", "Leertaste", "空格键"); a character key comes from the caps the current layout renders.
import AppKit
import OverbrightCore

/// A key equivalent of an `NSMenuItem`.
struct MenuKeyEquivalent: Equatable {
    /// The key (lowercase for letters; AppKit's function-key characters for named keys).
    let key: String
    /// The modifiers.
    let modifiers: NSEvent.ModifierFlags

    /// The key equivalent of `id`'s live binding, nil when the shortcut is cleared, in conflict or has a key a menu
    /// cannot show.
    static func of(_ id: ShortcutID, in shortcuts: any ShortcutCenter) -> MenuKeyEquivalent? {
        guard case .registered(let combo) = shortcuts.state(id) else { return nil }
        if let named = namedKey(code: combo.keyCode) {
            return MenuKeyEquivalent(key: named, modifiers: flags(combo.modifiers))
        }
        guard let caps = shortcuts.displayString(id) else { return nil }
        return parse(caps, modifiers: combo.modifiers)
    }

    /// The menu character of a named key by its `kVK_*` code (nil for a character key).
    static func namedKey(code: UInt16) -> String? {
        if let named = namedKeyCodes[code] { return named }
        guard let number = functionKeyCodes[code], let scalar = UnicodeScalar(NSF1FunctionKey + number - 1) else {
            return nil
        }
        return String(Character(scalar))
    }

    /// The key equivalent of key caps such as "⌃⌥⌘B" (the modifiers come from the combo, the key from the caps the
    /// center rendered in the current layout).
    static func parse(_ caps: String, modifiers: KeyCombo.Modifiers) -> MenuKeyEquivalent? {
        let key = String(caps.drop { modifierGlyphs.contains($0) })
        guard !key.isEmpty, let equivalent = equivalent(of: key) else { return nil }
        return MenuKeyEquivalent(key: equivalent, modifiers: flags(modifiers))
    }

    /// Applies the key equivalent to `item`, or clears it.
    static func apply(_ equivalent: MenuKeyEquivalent?, to item: NSMenuItem) {
        item.keyEquivalent = equivalent?.key ?? ""
        item.keyEquivalentModifierMask = equivalent?.modifiers ?? []
    }

    /// "⌃⌥⌘B" for display (dumps and tests).
    var displayText: String {
        var text = ""
        if modifiers.contains(.control) { text += "⌃" }
        if modifiers.contains(.option) { text += "⌥" }
        if modifiers.contains(.shift) { text += "⇧" }
        if modifiers.contains(.command) { text += "⌘" }
        return text + (Self.namedKeys.first { $0.value == key }?.key ?? key.uppercased())
    }

    // MARK: Private

    private static let modifierGlyphs: Set<Character> = ["⌃", "⌥", "⇧", "⌘"]

    /// Named keys as the shortcut center renders them, and their menu characters.
    private static let namedKeys: [String: String] = [
        "Space": " ", "↩": "\r", "⇥": "\t", "⌫": "\u{8}", "⎋": "\u{1b}",
        "←": String(UnicodeScalar(NSLeftArrowFunctionKey).map(Character.init) ?? " "),
        "→": String(UnicodeScalar(NSRightArrowFunctionKey).map(Character.init) ?? " "),
        "↑": String(UnicodeScalar(NSUpArrowFunctionKey).map(Character.init) ?? " "),
        "↓": String(UnicodeScalar(NSDownArrowFunctionKey).map(Character.init) ?? " "),
    ]

    /// Named keys by `kVK_*` code: Return, Tab, Space, Delete, Esc and the arrows.
    private static let namedKeyCodes: [UInt16: String] = [
        0x24: "\r", 0x30: "\t", 0x31: " ", 0x33: "\u{8}", 0x35: "\u{1b}",
        0x7B: String(UnicodeScalar(NSLeftArrowFunctionKey).map(Character.init) ?? " "),
        0x7C: String(UnicodeScalar(NSRightArrowFunctionKey).map(Character.init) ?? " "),
        0x7D: String(UnicodeScalar(NSDownArrowFunctionKey).map(Character.init) ?? " "),
        0x7E: String(UnicodeScalar(NSUpArrowFunctionKey).map(Character.init) ?? " "),
    ]

    /// F1–F12 by `kVK_*` code, as their number.
    private static let functionKeyCodes: [UInt16: Int] = [
        0x7A: 1, 0x78: 2, 0x63: 3, 0x76: 4, 0x60: 5, 0x61: 6, 0x62: 7, 0x64: 8, 0x65: 9, 0x6D: 10, 0x67: 11, 0x6F: 12,
    ]

    private static func equivalent(of key: String) -> String? {
        if let named = namedKeys[key] { return named }
        guard key.count == 1 else { return nil }
        return key.lowercased()
    }

    private static func flags(_ modifiers: KeyCombo.Modifiers) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers.contains(.command) { flags.insert(.command) }
        if modifiers.contains(.option) { flags.insert(.option) }
        if modifiers.contains(.control) { flags.insert(.control) }
        if modifiers.contains(.shift) { flags.insert(.shift) }
        return flags
    }
}
