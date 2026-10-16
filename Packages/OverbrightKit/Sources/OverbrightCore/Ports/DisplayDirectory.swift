// OverbrightCore/Ports/DisplayDirectory.swift — the online displays (implemented by OverbrightDisplays).
// ARCHITECTURE.md §3.6, §7.1, D9.
// Contract rule (§10.0): a requirement added after WP0a lands only together with a default implementation in a
// protocol extension in this file.
import Observation

/// The observable list of online displays.
@MainActor public protocol DisplayDirectory: AnyObject, Observable {
    /// Online displays, built-in first, then by key. Changes after the debounced reconfiguration callback, and at
    /// once (without the debounce) when a display is removed.
    var displays: [DisplayFacts] { get }
    /// Increments on every change of `displays`; observers re-read `displays`.
    var generation: Int { get }
    /// The facts of one online display, nil when it is not online.
    func facts(for key: DisplayKey) -> DisplayFacts?
}
