// OverbrightCore/Shortcuts/GlobalShortcut.swift — a shortcut and its default combo (nil for every shortcut as shipped).
// ARCHITECTURE.md §3.7, D17.

/// A global shortcut and its default combo (none ships one, D17: the user records it in Settings ▸ Shortcuts).
public nonisolated struct GlobalShortcut: Hashable, Sendable {
    /// The shortcut.
    public var id: ShortcutID
    /// The default combo; nil = no default.
    public var defaultCombo: KeyCombo?
    /// A catalog entry.
    public init(id: ShortcutID, defaultCombo: KeyCombo?) { self.id = id; self.defaultCombo = defaultCombo }
}
