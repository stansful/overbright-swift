// OverbrightCore/Shortcuts/ShortcutState.swift — whether a shortcut is registered (ported from Cranny). ARCHITECTURE.md §3.7.

/// Whether a global shortcut is live.
public nonisolated enum ShortcutState: Hashable, Sendable {
    /// No combo.
    case off
    /// Registered with the system.
    case registered(KeyCombo)
    /// `RegisterEventHotKey` failed (another app owns it).
    case conflict(KeyCombo)
}
