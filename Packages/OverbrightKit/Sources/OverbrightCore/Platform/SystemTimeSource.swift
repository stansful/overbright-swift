// OverbrightCore/Platform/SystemTimeSource.swift — the real `TimeSource`. ARCHITECTURE.md §3.6, §8.1 rule 5.
import Foundation

/// The real time source: `ContinuousClock` (keeps counting while the Mac sleeps) and the system's wall clock.
/// Sleeps use `Task.sleep` with 10 % tolerance, so the system can coalesce wake-ups (energy, D22).
public nonisolated struct SystemTimeSource: TimeSource {
    private let origin: ContinuousClock.Instant
    /// A time source whose `now` counts from this moment.
    public init() { origin = ContinuousClock.now }
    /// Time since the source was made.
    public var now: MonotonicInstant { MonotonicInstant(sinceOrigin: origin.duration(to: ContinuousClock.now)) }
    /// The system's wall clock.
    public var wallClock: Date { Date() }
    /// `Task.sleep(for:tolerance:)` with 10 % tolerance; throws `CancellationError` when the task is cancelled.
    public func sleep(for duration: Duration) async throws {
        guard duration > .zero else { try Task.checkCancellation(); return }
        try await Task.sleep(for: duration, tolerance: duration / 10)
    }
}
