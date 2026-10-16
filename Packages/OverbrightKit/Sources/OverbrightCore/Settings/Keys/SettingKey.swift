// OverbrightCore/Settings/Keys/SettingKey.swift — a typed settings key with its default, ported from Cranny's
// `SettingKey` (`module` → `namespace`). ARCHITECTURE.md §3.8.

/// A typed key with its default, ported from Cranny's `SettingKey` (`module` → `namespace`). `SettingsStore`
/// stores it as JSON under "overbright." + `id`; equality and hashing use `id`.
public nonisolated struct SettingKey<Value: Codable & Sendable & Equatable>: Sendable, Hashable {
    /// The namespace (first component of the stored key).
    public let namespace: SettingsNamespace
    /// The key's name within its namespace. Never rename one that shipped.
    public let name: String
    /// The value while nothing is stored; storing it removes the stored value.
    public let defaultValue: Value
    /// "<namespace>.<name>", built once: every read, hash and `==` uses it.
    public let id: String
    /// A key in `namespace` named `name`.
    public init(_ namespace: SettingsNamespace, _ name: String, default defaultValue: Value) {
        self.namespace = namespace; self.name = name; self.defaultValue = defaultValue
        id = "\(namespace.rawValue).\(name)"
    }
    /// Keys are equal when their ids are, whatever their defaults.
    public static func == (a: Self, b: Self) -> Bool { a.id == b.id }
    /// Hashes the id.
    public func hash(into h: inout Hasher) { h.combine(id) }
}
