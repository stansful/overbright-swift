// OverbrightChannel/ChannelStore.swift — where the control's snapshot and token live. ARCHITECTURE.md §7.7, §8.2; D25.
// Nonisolated: the extension's value provider and intent read it off the main actor.

/// A tiny string store for the channel's two values: the preferences snapshot and the `set=on` token. The app and the
/// extension use `PreferencesChannelStore` (the app's own preferences domain); tests use `InMemoryChannelStore`, so no
/// test ever writes the real domain.
public protocol ChannelStore: Sendable {
    /// The string stored under `key`, nil when there is none.
    func string(forKey key: String) -> String?
    /// Stores `value` under `key`; nil removes it.
    func set(_ value: String?, forKey key: String)
}
