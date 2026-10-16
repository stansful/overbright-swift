// OverbrightCore/Shortcuts/KeyCombo+KeyCaps.swift — key caps of a `KeyCombo` in a keyboard layout. ARCHITECTURE.md
// §3.7, §8.8 ("Key caps are never literal"); DESIGN.md §12.5, §16. Staged by WP0b in Additions/ (new nested types and
// extension methods only); folded here by WP13.
//
// `KeyCombo.keyCode` is a key POSITION (kVK_*). What the key cap shows depends on the keyboard layout: the key that
// sits at kVK_ANSI_Equal reads "=" on a US layout, "´" on a German one and "-" on a French one. One function renders
// the caps for every surface (`ShortcutCenter.displayString`, the menu's key equivalents, the recorder), so the copy,
// the menu and Settings never disagree (DESIGN.md §16).
//
// The character is the layout's COMMAND layer (`UCKeyTranslate` with ⌘ held, no dead keys), which is what macOS menus
// show: a Russian layout gives "B" for kVK_ANSI_B, German gives "´" and "ß", French gives "à" and ")". Reading a
// layout (`current()`, `named(_:)`) uses the Text Input Sources API, which must run on the main thread; translating a
// key with the copied layout data is pure and thread-safe. Nothing here selects, enables or changes an input source:
// `named(_:)` only reads an installed layout's table (tests and the Debug `-OverbrightQAKeyboardLayout` default).
import Carbon
import Foundation

extension KeyCombo {
    /// The key-translation table of one keyboard layout (`kTISPropertyUnicodeKeyLayoutData`), copied once.
    public nonisolated struct KeyboardLayout: Sendable, Equatable {
        /// The input source identifier ("com.apple.keylayout.German").
        public let identifier: String
        /// The `UCKeyboardLayout` bytes.
        let data: Data

        /// A layout from its identifier and table bytes (tests build none; they read installed layouts).
        init(identifier: String, data: Data) {
            self.identifier = identifier
            self.data = data
        }

        /// The keyboard layout in use now, or nil when it has no Unicode table (some input methods): callers then
        /// fall back to `named(KeyboardLayout.us)`. Main thread only (Text Input Sources).
        @MainActor public static func current() -> KeyboardLayout? {
            guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue() else { return nil }
            return layout(of: source)
        }

        /// An installed layout by identifier ("com.apple.keylayout.French"), enabled or not; nil when this Mac has
        /// none by that name. Read-only: the user's input sources are not touched. Main thread only.
        @MainActor public static func named(_ identifier: String) -> KeyboardLayout? {
            let filter = [kTISPropertyInputSourceID as String: identifier] as CFDictionary
            guard let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource],
                  let source = list.first else { return nil }
            return layout(of: source)
        }

        /// The layout key caps are drawn in: the current one; in Debug builds the `-OverbrightQAKeyboardLayout <id>`
        /// default overrides it for snapshots (ARCHITECTURE.md §8.5). Falls back to the US layout.
        @MainActor public static func forDisplay() -> KeyboardLayout? {
            #if DEBUG
            if let override = UserDefaults.standard.string(forKey: qaOverrideKey), let layout = named(override) {
                return layout
            }
            #endif
            return current() ?? named(us)
        }

        /// The identifier of the US layout (the fallback, and the layout DESIGN.md writes defaults in).
        public static let us = "com.apple.keylayout.US"

        /// The Debug default that renders key caps in another layout (`-OverbrightQAKeyboardLayout <id>`).
        public static let qaOverrideKey = "OverbrightQAKeyboardLayout"

        /// The character `keyCode` types with ⌘ held (the layer menus show), without dead-key composition; nil for a
        /// key the layout leaves empty.
        public func character(forKeyCode keyCode: UInt16) -> String? {
            data.withUnsafeBytes { raw -> String? in
                guard let layout = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
                var deadKeys: UInt32 = 0
                var length = 0
                var characters = [UniChar](repeating: 0, count: 4)
                let commandLayer = UInt32((cmdKey >> 8) & 0xFF)
                let status = UCKeyTranslate(layout, keyCode, UInt16(kUCKeyActionDisplay), commandLayer,
                                            UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                            &deadKeys, characters.count, &length, &characters)
                guard status == noErr, length > 0 else { return nil }
                return String(utf16CodeUnits: characters, count: length)
            }
        }

        @MainActor private static func layout(of source: TISInputSource) -> KeyboardLayout? {
            guard let table = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData),
                  let idPointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return nil }
            let data = Unmanaged<CFData>.fromOpaque(table).takeUnretainedValue() as Data
            let identifier = Unmanaged<CFString>.fromOpaque(idPointer).takeUnretainedValue() as String
            return KeyboardLayout(identifier: identifier, data: data)
        }
    }

    /// The key caps of this combo in `layout`: modifiers in Apple's order ⌃ ⌥ ⇧ ⌘, then the key ("⌃⌥⌘B", "⌃⌥⌘´" on
    /// a German layout). `spaceName` is the caller's localized word for the space bar.
    public func keyCaps(in layout: KeyboardLayout?, spaceName: String = "␣") -> String {
        Self.symbols(for: modifiers) + Self.keyName(keyCode, in: layout, spaceName: spaceName)
    }

    /// "⌃⌥⇧⌘" for the modifiers that are held, in Apple's order.
    public static func symbols(for modifiers: Modifiers) -> String {
        var text = ""
        if modifiers.contains(.control) { text += "⌃" }
        if modifiers.contains(.option) { text += "⌥" }
        if modifiers.contains(.shift) { text += "⇧" }
        if modifiers.contains(.command) { text += "⌘" }
        return text
    }

    /// The cap of one key: a function key ("F5") or a named key ("↩", "←") by its code; otherwise the layout's
    /// character, upper-cased when that stays one character ("b" → "B", but "ß" stays "ß"); "#<code>" when the layout
    /// has nothing for it.
    public static func keyName(_ keyCode: UInt16, in layout: KeyboardLayout?, spaceName: String = "␣") -> String {
        if let name = functionKeys[keyCode] ?? namedKeys[keyCode] { return name }
        if keyCode == UInt16(kVK_Space) { return spaceName }
        let character = (layout?.character(forKeyCode: keyCode) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !character.isEmpty else { return "#\(keyCode)" }
        let upper = character.uppercased()
        return upper.count == character.count ? upper : character
    }

    /// Function keys by virtual key code (HIToolbox/Events.h): layout-independent caps.
    public static let functionKeys: [UInt16: String] = [
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
        103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18", 80: "F19",
        90: "F20",
    ]

    /// Named keys by virtual key code: Return, Enter, Tab, Delete, Forward Delete, Escape, arrows, Home, End, Page Up,
    /// Page Down (the symbols macOS menus use).
    public static let namedKeys: [UInt16: String] = [
        36: "↩", 76: "⌤", 48: "⇥", 51: "⌫", 117: "⌦", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑", 115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
    ]
}
