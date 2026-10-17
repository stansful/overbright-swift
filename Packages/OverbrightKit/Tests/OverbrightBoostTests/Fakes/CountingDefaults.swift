// OverbrightBoostTests/Fakes/CountingDefaults.swift — an in-memory UserDefaults that counts the writes per key, so a
// test can tell how often the settings store reached `defaults` (each write is a JSON encode and, on the real store, a
// cfprefsd message). Test-only; Core's `InMemoryDefaults` is unchanged and does the storing.
import Foundation
import OverbrightCore
import os

/// Forwards to an `InMemoryDefaults`; counts `set(_:forKey:)` and `removeObject(forKey:)` per key.
nonisolated final class CountingDefaults: UserDefaults, @unchecked Sendable {
    private let inner = InMemoryDefaults()
    private let counts = OSAllocatedUnfairLock<[String: Int]>(initialState: [:])

    /// Writes (sets and removals) of `key` so far.
    func writes(of key: String) -> Int { counts.withLock { $0[key] ?? 0 } }

    override func object(forKey defaultName: String) -> Any? { inner.object(forKey: defaultName) }

    override func data(forKey defaultName: String) -> Data? { inner.data(forKey: defaultName) }

    override func set(_ value: Any?, forKey defaultName: String) {
        counts.withLock { $0[defaultName, default: 0] += 1 }
        inner.set(value, forKey: defaultName)
    }

    override func removeObject(forKey defaultName: String) {
        counts.withLock { $0[defaultName, default: 0] += 1 }
        inner.removeObject(forKey: defaultName)
    }

    override func dictionaryRepresentation() -> [String: Any] { inner.dictionaryRepresentation() }
}
