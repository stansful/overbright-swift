// OverbrightCore/Shortcuts/ShortcutCatalog.swift — the global shortcuts and their defaults. ARCHITECTURE.md §3.7, D17.

/// Defaults avoid ⌃⌥Space (input sources), ⌃⌥⌘8 and ⌃⌥⌘,/. (accessibility) and ⌃⌥⌘V / ⌃⌥⌘D, another booster's
/// defaults (D17). Key codes are kVK_ANSI_* POSITIONS (B = 11, Equal = 24, Minus = 27, 9 = 25, 0 = 29); the key caps
/// shown in copy and menus come from the current keyboard layout (`ShortcutCenter.displayString`).
public nonisolated enum ShortcutCatalog {
    static let hyper: KeyCombo.Modifiers = [.control, .option, .command]
    /// Every global shortcut, in menu order.
    public static let all: [GlobalShortcut] = [
        GlobalShortcut(id: .toggle, defaultCombo: KeyCombo(keyCode: 11, modifiers: hyper)),     // ⌃⌥⌘B
        GlobalShortcut(id: .brighter, defaultCombo: KeyCombo(keyCode: 24, modifiers: hyper)),   // ⌃⌥⌘= (US)
        GlobalShortcut(id: .lessBright, defaultCombo: KeyCombo(keyCode: 27, modifiers: hyper)), // ⌃⌥⌘- (US)
        GlobalShortcut(id: .max, defaultCombo: nil),
        GlobalShortcut(id: .standard, defaultCombo: KeyCombo(keyCode: 29, modifiers: hyper)),   // ⌃⌥⌘0 (US)
        GlobalShortcut(id: .dimToggle, defaultCombo: KeyCombo(keyCode: 25, modifiers: hyper)),  // ⌃⌥⌘9 (US)
        GlobalShortcut(id: .fillLight, defaultCombo: nil),
    ]
}
