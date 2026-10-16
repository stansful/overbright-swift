// OverbrightAppShell/StatusItem/MenuKeyEquivalent.swift — a global shortcut shown as a menu item's key equivalent, so
// the menu always tells the truth about the live binding: its key caps in the CURRENT keyboard layout, the new
// combination after a rebind, nothing when the shortcut is cleared or failed to register. DESIGN.md §4.3, §16;
// ARCHITECTURE.md §3.6 (`ShortcutCenter.displayString` is "the same code as the menu's live key equivalents").
// Ported idea from Cranny's MenuKeyEquivalent (the owner's MIT code), rebuilt on `displayString`.
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
        guard case .registered(let combo) = shortcuts.state(id), let caps = shortcuts.displayString(id) else { return nil }
        return parse(caps, modifiers: combo.modifiers)
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
