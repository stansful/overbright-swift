// OverbrightCore/Platform/SystemTimeSource.swift — the real `TimeSource`. ARCHITECTURE.md §3.6, §8.1 rule 5.
import Foundation

/// The real time source: `ContinuousClock` (keeps counting while the Mac sleeps) and the system's wall clock.
/// Sleeps use `Task.sleep` with 10 % tolerance, at most `maximumTolerance`, so the system can coalesce wake-ups
/// (energy, D22) without letting an hour-long deadline end minutes late.
public nonisolated struct SystemTimeSource: TimeSource {
    /// The largest tolerance of one sleep: a sleep of 10 s or more ends at most this late.
    static let maximumTolerance: Duration = .seconds(1)

    private let origin: ContinuousClock.Instant
    /// A time source whose `now` counts from this moment.
    public init() { origin = ContinuousClock.now }
    /// Time since the source was made.
    public var now: MonotonicInstant { MonotonicInstant(sinceOrigin: origin.duration(to: ContinuousClock.now)) }
    /// The system's wall clock.
    public var wallClock: Date { Date() }
    /// `Task.sleep(for:tolerance:)` with `tolerance(for:)`; throws `CancellationError` when the task is cancelled.
    public func sleep(for duration: Duration) async throws {
        guard duration > .zero else { try Task.checkCancellation(); return }
        try await Task.sleep(for: duration, tolerance: Self.tolerance(for: duration))
    }

    /// 10 % of `duration`, at most `maximumTolerance` (libdispatch caps the leeway only of repeating timers, so a
    /// one-shot "Pause for 1 Hour" sleep could otherwise end 6 minutes late).
    static func tolerance(for duration: Duration) -> Duration {
        min(duration / 10, maximumTolerance)
    }
}
