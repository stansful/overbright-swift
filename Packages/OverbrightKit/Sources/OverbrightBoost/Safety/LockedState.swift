// OverbrightBoost/Safety/LockedState.swift — a value behind an `NSLock`, for the safety classes that run off the main
// actor (the hang watchdog's queue, the signal queue). ARCHITECTURE.md §8.1 rules 4 and 7. Any thread.
import Foundation

/// A mutable value shared across threads. `@unchecked Sendable`: the value is only reached through `withLock(_:)`,
/// which holds `lock` (§8.1 rule 7). Never call another `LockedState` or the safety ledger inside `body` while it
/// could be waiting on this lock: the watchdog and the signal handlers keep their own state lock and the ledger lock
/// strictly apart.
nonisolated final class LockedState<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    /// A box holding `value`.
    init(_ value: Value) { self.value = value }

    /// Runs `body` with the value while holding the lock.
    func withLock<T>(_ body: (inout Value) throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body(&value)
    }
}
