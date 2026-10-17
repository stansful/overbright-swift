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
    /// Real: Task.sleep with 10 % tolerance (at most 1 s). Manual: suspends until `advance(by:)` passes the deadline.
    func sleep(for duration: Duration) async throws
}

extension TimeSource {
    /// The next point of the `period` grid of this time source's clock (the multiples of `period` since its origin)
    /// strictly after `now`: never `now` itself, at most one `period` away. Activities that share one time source and
    /// one period and each wait for this point wake together, so the system serves them with one wake-up instead of
    /// one per activity (ARCHITECTURE.md §3.6: the composition root hands every service the same `SystemTimeSource`).
    /// Not a requirement, so every conformer has it as is (§10.0).
    public func nextGridPoint(every period: Duration) -> MonotonicInstant {
        MonotonicInstant.nextGridPoint(after: now, every: period)
    }
}

extension MonotonicInstant {
    /// The first multiple of `period` since the origin that lies strictly after `instant`, so the result is in
    /// `(instant, instant + period]`: on a grid point it is the next one, just before one it is that one. A period
    /// that is not positive has no grid: `instant` itself. Pure, for `TimeSource.nextGridPoint(every:)` and its tests.
    public static func nextGridPoint(after instant: MonotonicInstant, every period: Duration) -> MonotonicInstant {
        guard period > .zero else { return instant }
        let periods = (instant.sinceOrigin / period).rounded(.down)
        // Beyond 2^52 periods (about 285 million years of 2 s) a Double no longer counts single periods.
        guard periods.magnitude < 0x1p52 else { return instant + period }
        // The Double quotient may be off by one period either way at a boundary; Duration arithmetic is exact.
        var point = period * (Int64(periods) + 1)
        while point - period > instant.sinceOrigin { point -= period }
        while point <= instant.sinceOrigin { point += period }
        return MonotonicInstant(sinceOrigin: point)
    }
}
