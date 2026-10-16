// OverbrightCore/Fakes/ManualTimeSource.swift — a TimeSource that moves only when a test says so. ARCHITECTURE.md §3.9,
// §9.1 (no real sleeping in tests, never a short real-time wait).
import Foundation

/// A `TimeSource` driven by the test: `sleep(for:)` suspends until `advance(by:)` moves time past the deadline.
/// Sleepers wake in deadline order (ties in the order they started sleeping); a cancelled sleeper throws
/// `CancellationError` at once. Nonisolated and lock-protected (`@unchecked Sendable`: every stored property is behind
/// `lock`), like the real one, so off-main code (the hang watchdog) can read it too.
public nonisolated final class ManualTimeSource: TimeSource, @unchecked Sendable {
    private struct Sleeper {
        let id: UInt64
        let deadline: MonotonicInstant
        let continuation: CheckedContinuation<Void, any Error>
    }

    private let lock = NSLock()
    private var current: MonotonicInstant
    /// The wall clock at `wallAnchorInstant` (the wall clock is derived, so long runs never accumulate rounding).
    private var wallAnchor: Date
    private var wallAnchorInstant: MonotonicInstant
    private var sleepers: [Sleeper] = []
    private var cancelledEarly: Set<UInt64> = []
    private var lastID: UInt64 = 0

    /// A time source at `MonotonicInstant(sinceOrigin: .zero)` whose wall clock reads `start` (a fixed date, so tests
    /// are reproducible: 2026-05-08 22:13:20 UTC by default).
    public init(start: Date = Date(timeIntervalSinceReferenceDate: 800_000_000)) {
        current = MonotonicInstant(sinceOrigin: .zero)
        wallAnchor = start
        wallAnchorInstant = current
    }

    /// The monotonic time now.
    public var now: MonotonicInstant { lock.withLock { current } }
    /// The wall clock now (moves with `advance(by:)`; `setWallClock(_:)` jumps it alone).
    public var wallClock: Date { lock.withLock { wallAnchor.addingTimeInterval((current - wallAnchorInstant).timeInterval) } }
    /// Number of tasks sleeping now.
    public var sleeperCount: Int { lock.withLock { sleepers.count } }
    /// The earliest pending deadline, if any.
    public var nextDeadline: MonotonicInstant? { lock.withLock { sleepers.map(\.deadline).min() } }

    /// Suspends until `advance(by:)` passes `now + duration`; returns at once for a zero or negative duration.
    public func sleep(for duration: Duration) async throws {
        try Task.checkCancellation()
        let id = lock.withLock { () -> UInt64 in lastID += 1; return lastID }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let outcome: Result<Bool, CancellationError> = lock.withLock {
                    if cancelledEarly.remove(id) != nil { return .failure(CancellationError()) }
                    if duration <= .zero { return .success(true) }
                    sleepers.append(Sleeper(id: id, deadline: current + duration, continuation: continuation))
                    return .success(false)
                }
                switch outcome {
                case .success(true): continuation.resume()
                case .success(false): break
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            let continuation: CheckedContinuation<Void, any Error>? = lock.withLock {
                if let index = sleepers.firstIndex(where: { $0.id == id }) { return sleepers.remove(at: index).continuation }
                cancelledEarly.insert(id)
                return nil
            }
            continuation?.resume(throwing: CancellationError())
        }
    }

    /// Moves time forward by `duration`. Time stops at each pending deadline on the way, wakes every sleeper due then
    /// (in order) and yields `yields` times so the woken tasks run (and may sleep again) before time moves on: a sleep
    /// started by a woken task that ends within this advance is woken in the same call.
    public func advance(by duration: Duration, yields: Int = 25) async {
        let target = now + duration
        while true {
            let due: [Sleeper] = lock.withLock {
                guard let next = sleepers.map(\.deadline).min(), next <= target else { return [] }
                move(to: next)
                let due = sleepers.filter { $0.deadline <= next }
                sleepers.removeAll { $0.deadline <= next }
                return due.sorted { ($0.deadline, $0.id) < ($1.deadline, $1.id) }
            }
            if due.isEmpty { break }
            for sleeper in due { sleeper.continuation.resume() }
            for _ in 0..<yields { await Task.yield() }
        }
        lock.withLock { move(to: target) }
        for _ in 0..<yields { await Task.yield() }
    }

    /// Jumps the wall clock alone (the user set the clock, a time zone change); the monotonic time does not move.
    public func setWallClock(_ date: Date) {
        lock.withLock { wallAnchor = date; wallAnchorInstant = current }
    }

    /// Moves both clocks to `instant` (never backwards). Call with `lock` held.
    private func move(to instant: MonotonicInstant) {
        if instant > current { current = instant }
    }
}
