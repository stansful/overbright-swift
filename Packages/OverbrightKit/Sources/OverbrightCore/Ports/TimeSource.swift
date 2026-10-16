// OverbrightCore/Ports/TimeSource.swift — the time port (named TimeSource: `Clock` is an SDK type, D21).
// ARCHITECTURE.md §3.6, §8.1 rule 5. Real: `SystemTimeSource`; fake: `ManualTimeSource`.
// Contract rule (§10.0): a requirement added after WP0a lands only together with a default implementation in a
// protocol extension in this file.
import Foundation

/// Monotonic time, the wall clock and sleeping. Nonisolated and `Sendable`: the hang watchdog and the journal use it
/// off the main actor.
public protocol TimeSource: Sendable {
    /// The monotonic clock now.
    var now: MonotonicInstant { get }
    /// The wall clock now (deadlines the user sees: pause, auto-off, schedule).
    var wallClock: Date { get }
    /// Real: Task.sleep with 10 % tolerance. Manual: suspends until `advance(by:)` passes the deadline.
    func sleep(for duration: Duration) async throws
}
