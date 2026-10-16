// OverbrightHotKeys/HotKeyRegistrar.swift — the slice of Carbon's hot-key API that `HotKeyCenter` uses, behind a
// protocol so tests drive the center without registering real system-wide shortcuts. ARCHITECTURE.md §3.7, D17.
import OverbrightCore

/// Registers and unregisters system-wide hot keys and delivers their presses.
@MainActor public protocol HotKeyRegistrar: AnyObject {
    /// Called with the id `register(_:)` returned when that hot key is pressed, on the main actor.
    var onPress: (@MainActor (UInt32) -> Void)? { get set }
    /// Registers `combo` and returns its id (unique for the process); nil when the system refuses it (another app
    /// owns the combination, or the event handler could not be installed).
    func register(_ combo: KeyCombo) -> UInt32?
    /// Unregisters the hot key `id` (a no-op for an unknown id).
    func unregister(_ id: UInt32)
}
