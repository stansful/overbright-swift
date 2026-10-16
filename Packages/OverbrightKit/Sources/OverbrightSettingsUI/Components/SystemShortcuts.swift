// OverbrightSettingsUI/Components/SystemShortcuts.swift — a best-effort check of an Overbright shortcut against the
// enabled macOS shortcuts (DESIGN.md §7.6: "macOS uses this for ‹name of the system shortcut›"; D17). Ported from
// Cranny's SystemShortcuts (the owner's MIT code). `RegisterEventHotKey` does not fail on a system combination, so
// Settings reads the `AppleSymbolicHotKeys` dictionary of the `com.apple.symbolichotkeys` domain (read-only; format on
// macOS 27: `{ "<id>": { enabled, value: { parameters: [ascii, keyCode, NSEvent flags] } } }`). The domain lists only
// shortcuts the user changed, so the well-known defaults fill the gaps (D17's neighbours included: the accessibility
// shortcuts ⌃⌥⌘8, ⌃⌥⌘, and ⌃⌥⌘.). Parsing is pure (tested).
import AppKit
import Foundation
import OverbrightCore

/// The enabled macOS shortcuts.
nonisolated enum SystemShortcuts {
    /// The enabled shortcuts, read off the main actor (a preferences domain of another process).
    @concurrent static func load() async -> [SystemShortcut] {
        enabled(from: readDomain())
    }

    /// The enabled shortcuts: the user's entries from the domain, plus the defaults of well-known ids it does not list.
    static func enabled(from domain: [String: Any]?) -> [SystemShortcut] {
        var byID: [Int: SystemShortcut?] = [:]
        for (key, raw) in domain ?? [:] {
            guard let id = Int(key), let entry = raw as? [String: Any] else { continue }
            byID[id] = parse(id: id, entry: entry)
        }
        for (id, shortcut) in defaults where byID[id] == nil { byID[id] = shortcut }
        return byID.values.compactMap { $0 }.sorted { $0.id < $1.id }
    }

    /// One domain entry; nil when it is disabled, has no key or is not a "standard" shortcut.
    static func parse(id: Int, entry: [String: Any]) -> SystemShortcut? {
        guard (entry["enabled"] as? Bool) ?? (entry["enabled"] as? NSNumber)?.boolValue ?? false,
              let value = entry["value"] as? [String: Any],
              let parameters = value["parameters"] as? [Any], parameters.count >= 3,
              let rawKeyCode = (parameters[1] as? NSNumber)?.intValue, rawKeyCode != 0xFFFF,
              let keyCode = UInt16(exactly: rawKeyCode),                      // never traps on a bad entry (§9.2)
              let flags = (parameters[2] as? NSNumber)?.intValue else { return nil }
        return SystemShortcut(id: id, keyCode: keyCode, modifiers: modifiers(flags))
    }

    /// `NSEvent.ModifierFlags` raw bits → `KeyCombo.Modifiers` (Fn, which arrows and F-keys carry, is ignored).
    static func modifiers(_ flags: Int) -> KeyCombo.Modifiers {
        var modifiers: KeyCombo.Modifiers = []
        if flags & (1 << 17) != 0 { modifiers.insert(.shift) }
        if flags & (1 << 18) != 0 { modifiers.insert(.control) }
        if flags & (1 << 19) != 0 { modifiers.insert(.option) }
        if flags & (1 << 20) != 0 { modifiers.insert(.command) }
        return modifiers
    }

    /// The first enabled macOS shortcut that uses `combo`.
    static func conflict(for combo: KeyCombo, in shortcuts: [SystemShortcut]) -> SystemShortcut? {
        shortcuts.first { $0.matches(combo) }
    }

    /// Reads the domain (no prompt: an ordinary preferences read). nil when it cannot be read.
    static func readDomain() -> [String: Any]? {
        UserDefaults(suiteName: "com.apple.symbolichotkeys")?.dictionary(forKey: "AppleSymbolicHotKeys")
    }

    /// The well-known defaults alone (before the domain is read).
    static let knownDefaults: [SystemShortcut] = enabled(from: nil)

    /// macOS defaults of shortcuts that collide most often: screenshots, Spaces, input sources, Spotlight, and the
    /// accessibility shortcuts next to Overbright's ⌃⌥⌘ defaults (invert colours, contrast).
    static let defaults: [Int: SystemShortcut] = {
        let hyper: KeyCombo.Modifiers = [.control, .option, .command]
        let list: [(Int, UInt16, KeyCombo.Modifiers)] = [
            (28, 20, [.shift, .command]), (29, 20, [.control, .shift, .command]),
            (30, 21, [.shift, .command]), (31, 21, [.control, .shift, .command]), (184, 23, [.shift, .command]),
            (32, 126, [.control]), (33, 125, [.control]), (79, 123, [.control]), (81, 124, [.control]),
            (60, 49, [.control]), (61, 49, [.control, .option]), (64, 49, [.command]), (65, 49, [.option, .command]),
            (98, 44, [.shift, .command]),
            (21, 28, hyper), (25, 47, hyper), (26, 43, hyper),
        ]
        return Dictionary(uniqueKeysWithValues: list.map { ($0.0, SystemShortcut(id: $0.0, keyCode: $0.1, modifiers: $0.2)) })
    }()

    /// A readable name for well-known ids; nil for the others.
    static func name(of id: Int) -> String? {
        switch id {
        case 28, 29, 30, 31, 184:
            String(localized: "screenshots", bundle: .module,
                   comment: "Settings ▸ Shortcuts: macOS shortcut group an Overbright shortcut collides with, inside “macOS uses this for %@.”")
        case 32: String(localized: "Mission Control", bundle: .module,
                        comment: "Settings ▸ Shortcuts: macOS shortcut an Overbright shortcut collides with (Apple’s name)")
        case 33: String(localized: "Application windows", bundle: .module,
                        comment: "Settings ▸ Shortcuts: macOS shortcut an Overbright shortcut collides with (Apple’s name in Keyboard Shortcuts)")
        case 79, 80, 81, 82: String(localized: "moving between Spaces", bundle: .module,
                                    comment: "Settings ▸ Shortcuts: macOS shortcut an Overbright shortcut collides with, inside “macOS uses this for %@.”")
        case 60, 61: String(localized: "switching input sources", bundle: .module,
                            comment: "Settings ▸ Shortcuts: macOS shortcut an Overbright shortcut collides with, inside “macOS uses this for %@.”")
        case 64: String(localized: "Spotlight", bundle: .module,
                        comment: "Settings ▸ Shortcuts: macOS shortcut an Overbright shortcut collides with (Apple’s name)")
        case 65: String(localized: "Finder search", bundle: .module,
                        comment: "Settings ▸ Shortcuts: macOS shortcut an Overbright shortcut collides with, inside “macOS uses this for %@.”")
        case 98: String(localized: "the Help menu", bundle: .module,
                        comment: "Settings ▸ Shortcuts: macOS shortcut an Overbright shortcut collides with, inside “macOS uses this for %@.”")
        case 21: String(localized: "Invert colors", bundle: .module,
                        comment: "Settings ▸ Shortcuts: macOS accessibility shortcut an Overbright shortcut collides with (Apple’s name)")
        case 25, 26: String(localized: "contrast", bundle: .module,
                            comment: "Settings ▸ Shortcuts: macOS accessibility shortcuts (increase and decrease contrast), inside “macOS uses this for %@.”")
        default: nil
        }
    }
}
