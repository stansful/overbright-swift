// OverbrightBoostTests/Fakes/CountingDefaults.swift — an in-memory UserDefaults that counts the writes per key, so a
// test can tell how often the settings store reached `defaults` (each write is a JSON encode and, on the real store, a
// cfprefsd message), and tells an observer about each one, so a test can check what had happened by then (quit writes
// the baselines first). Test-only; Core's `InMemoryDefaults` is unchanged and does the storing.
import Foundation
import OverbrightCore
import os

/// Forwards to an `InMemoryDefaults`; counts `set(_:forKey:)` and `removeObject(forKey:)` per key.
nonisolated final class CountingDefaults: UserDefaults, @unchecked Sendable {
    private let inner = InMemoryDefaults()
    private let counts = OSAllocatedUnfairLock<[String: Int]>(initialState: [:])
    private let observer = OSAllocatedUnfairLock<(@Sendable (String) -> Void)?>(initialState: nil)

    /// Writes (sets and removals) of `key` so far.
    func writes(of key: String) -> Int { counts.withLock { $0[key] ?? 0 } }

    /// Calls `body` with the key before every later write (set or removal).
    func observeWrites(_ body: @escaping @Sendable (String) -> Void) { observer.withLock { $0 = body } }

    private func count(_ key: String) {
        counts.withLock { $0[key, default: 0] += 1 }
        observer.withLock { $0 }?(key)
    }

    override func object(forKey defaultName: String) -> Any? { inner.object(forKey: defaultName) }

    override func data(forKey defaultName: String) -> Data? { inner.data(forKey: defaultName) }

    override func set(_ value: Any?, forKey defaultName: String) {
        count(defaultName)
        inner.set(value, forKey: defaultName)
    }

    override func removeObject(forKey defaultName: String) {
        count(defaultName)
        inner.removeObject(forKey: defaultName)
    }

    override func dictionaryRepresentation() -> [String: Any] { inner.dictionaryRepresentation() }
}
