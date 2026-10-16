// OverbrightCore/Ports/UpdateChecking.swift — the update check (implemented by OverbrightUpdates). ARCHITECTURE.md §3.6, D2.
// Contract rule (§10.0): a requirement added after WP0a lands only together with a default implementation in a
// protocol extension in this file.
import Observation

/// The GitHub Releases update check.
@MainActor public protocol UpdateChecking: AnyObject, Observable {
    /// False while the Info.plist repository key is empty: no network at all (D2).
    var isConfigured: Bool { get }
    /// The last result.
    var state: UpdateState { get }
    /// Checks now (no-op while not configured).
    func checkNow()
}
