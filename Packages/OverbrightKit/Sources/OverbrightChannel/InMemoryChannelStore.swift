// OverbrightChannel/InMemoryChannelStore.swift — a channel store for tests and previews. ARCHITECTURE.md §3.9 (fakes
// are public so every test target can use them), §7.7; D25.
import Foundation

/// A `ChannelStore` in memory, lock-protected (`@unchecked Sendable`: `values` is only touched under `lock`).
public nonisolated final class InMemoryChannelStore: ChannelStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String]

    /// A store holding `values`.
    public init(_ values: [String: String] = [:]) { self.values = values }

    /// Everything stored, for assertions.
    public var contents: [String: String] { lock.withLock { values } }

    /// The string under `key`.
    public func string(forKey key: String) -> String? { lock.withLock { values[key] } }

    /// Stores or removes `key`.
    public func set(_ value: String?, forKey key: String) { lock.withLock { values[key] = value } }
}
