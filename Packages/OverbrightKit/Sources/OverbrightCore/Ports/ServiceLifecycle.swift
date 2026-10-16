// OverbrightCore/Ports/ServiceLifecycle.swift — ordered start and stop of services. ARCHITECTURE.md §3.6, §7.4, D7, D23.
// Contract rule (§10.0): a requirement added after WP0a lands only together with a default implementation in a
// protocol extension in this file.

/// Ordered start/stop, owned by the composition root (Boost starts last and stops first, D7).
@MainActor public protocol ServiceLifecycle: AnyObject {
    /// For logs and the launch timing.
    var serviceName: String { get }
    /// Starts the service (the first I/O, hardware or network access).
    func start() async
    /// The normal stop (ramps). A user quit awaits it with a 1 s timeout before terminating (§7.4).
    func stop() async
    /// Synchronous fallback from `applicationWillTerminate`: no ramp, baselines written at once.
    func stopNow()
}
