// OverbrightCore/Shortcuts/ShortcutCatalog.swift — the global shortcuts and their defaults. ARCHITECTURE.md §3.7, D17.

/// Every global shortcut ships unbound (the owner's rule, 2026-10-20): nothing is registered until the user records a
/// combination in Settings ▸ Shortcuts. Key codes are kVK_ANSI_* POSITIONS; the key caps shown in copy and menus come
/// from the current keyboard layout (`ShortcutCenter.displayString`). Suggestions when recording should still avoid
/// ⌃⌥Space (input sources), ⌃⌥⌘8 and ⌃⌥⌘,/. (accessibility) and ⌃⌥⌘V / ⌃⌥⌘D, another booster's defaults (D17).
public nonisolated enum ShortcutCatalog {
    /// Every global shortcut, in menu order, all without a default combination.
    public static let all: [GlobalShortcut] = [
        GlobalShortcut(id: .toggle, defaultCombo: nil),
        GlobalShortcut(id: .brighter, defaultCombo: nil),
        GlobalShortcut(id: .lessBright, defaultCombo: nil),
        GlobalShortcut(id: .max, defaultCombo: nil),
        GlobalShortcut(id: .standard, defaultCombo: nil),
        GlobalShortcut(id: .dimToggle, defaultCombo: nil),
        GlobalShortcut(id: .fillLight, defaultCombo: nil),
    ]
}
