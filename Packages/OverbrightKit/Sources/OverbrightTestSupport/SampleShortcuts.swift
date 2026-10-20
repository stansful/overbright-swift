// OverbrightTestSupport/SampleShortcuts.swift — combinations the tests bind. ARCHITECTURE.md §3.7, D17.
//
// Every global shortcut ships unbound (D17, since 2026-10-20), so a test of what a bound shortcut does (registration,
// presses, key caps in a layout, the menu's key equivalents, Welcome's and Help's key caps) binds these first: the five
// combinations Overbright suggested before (⌃⌥⌘ with B, =, -, 0 and 9; kVK_ANSI positions), none of them a macOS
// shortcut (ARCHITECTURE.md Appendix A).
import OverbrightCore

/// Sample bindings for tests.
public nonisolated enum SampleShortcuts {
    /// ⌃⌥⌘.
    public static let hyper: KeyCombo.Modifiers = [.control, .option, .command]
    /// ⌃⌥⌘B: Turn on or off.
    public static let toggle = KeyCombo(keyCode: 11, modifiers: hyper)
    /// ⌃⌥⌘= (US): Brighter.
    public static let brighter = KeyCombo(keyCode: 24, modifiers: hyper)
    /// ⌃⌥⌘- (US): Less Bright.
    public static let lessBright = KeyCombo(keyCode: 27, modifiers: hyper)
    /// ⌃⌥⌘0 (US): Back to Standard.
    public static let standard = KeyCombo(keyCode: 29, modifiers: hyper)
    /// ⌃⌥⌘9 (US): Dim Below Minimum On or Off.
    public static let dimToggle = KeyCombo(keyCode: 25, modifiers: hyper)

    /// The five as stored bindings (`ShortcutSettings.bindings`); Max and Fill Light stay unbound.
    public static let bindings: [ShortcutID: KeyCombo?] = [
        .toggle: toggle, .brighter: brighter, .lessBright: lessBright, .standard: standard, .dimToggle: dimToggle,
    ]

    /// The catalog with the five as its defaults, for tests of how a default combination behaves (an override that
    /// equals it is removed, Reset All brings it back).
    public static let catalog: [GlobalShortcut] = ShortcutCatalog.all.map { shortcut in
        GlobalShortcut(id: shortcut.id, defaultCombo: bindings[shortcut.id] ?? nil)
    }
}
