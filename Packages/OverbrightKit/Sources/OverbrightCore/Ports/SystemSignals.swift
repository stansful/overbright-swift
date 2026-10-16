// OverbrightCore/Ports/SystemSignals.swift — system state and events (implemented by OverbrightSignals).
// ARCHITECTURE.md §3.6, §7.1, D9.
// Contract rule (§10.0): a requirement added after WP0a lands only together with a default implementation in a
// protocol extension in this file.
import Observation

/// The observable system snapshot plus discrete events.
@MainActor public protocol SystemSignals: AnyObject, Observable {
    /// Everything the policy needs from the system.
    var snapshot: SystemSnapshot { get }
    /// Delivers every event synchronously, in registration order; keep the token.
    func addEventObserver(_ handler: @escaping @MainActor (SystemEvent) -> Void) -> ObservationToken
    /// Starts the per-boost sources (battery percent, idle deadlines, watchdog full-screen re-check). D22.
    /// `true` also reads the power source and battery percent synchronously before returning.
    func setBoostActive(_ active: Bool)
    /// Synchronous `IOPSCopyPowerSourcesInfo` read into `snapshot.power` (master on, adapter → battery switch).
    func refreshPowerNow()
    /// The Focus filter's sink (IntentRouter → Signals); persisted so a launch reads the last directive.
    func setFocusDirective(_ directive: FocusDirective)
}
