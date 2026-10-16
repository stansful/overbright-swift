// OverbrightCore/Ports/ShortcutCenter.swift — global shortcuts (implemented by OverbrightHotKeys). ARCHITECTURE.md §3.6, D17.
// Contract rule (§10.0): a requirement added after WP0a lands only together with a default implementation in a
// protocol extension in this file.
import Observation

/// Registered global shortcuts and the recorder's hooks.
@MainActor public protocol ShortcutCenter: AnyObject, Observable {
    /// The live state of one shortcut.
    func state(_ id: ShortcutID) -> ShortcutState
    /// Stores and registers `combo` (nil clears it); returns the resulting state.
    @discardableResult func set(_ id: ShortcutID, _ combo: KeyCombo?) -> ShortcutState
    /// The recorder pauses every hot key while it listens.
    func setRecording(_ recording: Bool)
    /// The key caps of a registered shortcut in the CURRENT keyboard layout (the same code as the menu's live key
    /// equivalents), e.g. "⌃⌥⌘B"; nil when cleared or not registered. Copy never hard-codes key caps (DESIGN §16).
    func displayString(_ id: ShortcutID) -> String?
}
