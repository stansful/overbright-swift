// OverbrightCore/Settings/SettingsStore.swift — ported from Cranny's CrannyCore/Settings/SettingsStore.swift
// (the owner's MIT code): "cranny." → "overbright.", ModuleID → SettingsNamespace. One change: `binding(_:)` moved to
// OverbrightDesign (`SettingsStore+Binding.swift`) so Core imports no SwiftUI (D23). ARCHITECTURE.md §3.8, §8.2.
import Foundation
import Observation
import os

/// One observable box per key, so a view reading `settings[DisplaySettings.linkLevels]` is invalidated
/// only by that key (fine-grained Observation; no global "settings changed" storms).
///
/// Observable by hand rather than with `@Observable`: the macro's accessors evaluate the key path literal
/// `\.value` on every access, and in a generic class that instantiates the key path again each time (its generic
/// argument demangled): ≈ 750 ns per read, against ≈ 25 ns (≈ 75 ns while tracked) with the key path made once per
/// box. Every view body and `observe` closure reads settings, so this was the settings getter's whole cost.
@MainActor final class SettingBox<Value: Codable & Sendable & Equatable>: Observable {
    private let registrar = ObservationRegistrar()
    /// `\SettingBox<Value>.value`, made once.
    private let valuePath: KeyPath<SettingBox<Value>, Value>
    private var stored: Value

    /// The value; reading it inside a tracking closure tracks this box only. An equal value notifies nobody (as the
    /// macro's setter for an `Equatable` value).
    var value: Value {
        get {
            registrar.access(self, keyPath: valuePath)
            return stored
        }
        set {
            guard newValue != stored else { return }
            registrar.withMutation(of: self, keyPath: valuePath) { stored = newValue }
        }
    }

    init(_ value: Value) {
        stored = value
        valuePath = \SettingBox<Value>.value
    }
}

/// Typed, namespaced, observable settings (`services.settings`): reading a key inside a SwiftUI body or `observe`
/// tracks that key only. The store itself is NOT `@Observable`; each key's box is.
@MainActor public final class SettingsStore {
    /// Prefix of every stored key ("overbright.displays.linkLevels").
    public static let keyPrefix = "overbright."
    /// The store's `UserDefaults` (internal: the one-time upgrades in SettingsUpgrades.swift read it directly).
    let defaults: UserDefaults
    private var boxes: [String: AnyObject] = [:]
    private var reloadHandlers: [String: @MainActor () -> Void] = [:]
    /// The `defaults` writes `setDeferringWrite` still owes, by key id; each writes its key's value as it is then.
    private var deferredWrites: [String: @MainActor () -> Void] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// The app passes the shell's choice (`ShellDefaults`); tests and previews pass `InMemoryDefaults()`.
    public init(defaults: UserDefaults) { self.defaults = defaults }

    /// The value of `key`; setting the default removes it from disk.
    public subscript<V>(key: SettingKey<V>) -> V {
        get { box(key).value }
        set {
            let b = box(key)
            guard b.value != newValue else { return }
            b.value = newValue
            deferredWrites[key.id] = nil
            write(key, newValue)
        }
    }

    /// Sets `key` for every reader and observer at once, exactly as the subscript does, but owes the `defaults` write
    /// (a JSON encode and a cfprefsd message) until `writeDeferred()`: a value that changes many times a second (a level
    /// while a slider moves) is written once. A plain write of the key writes at once and settles what it owed.
    public func setDeferringWrite<V>(_ key: SettingKey<V>, _ newValue: V) {
        let b = box(key)
        guard b.value != newValue else { return }
        b.value = newValue
        deferredWrites[key.id] = { [weak self, weak b] in
            guard let self, let b else { return }
            self.write(key, b.value)
        }
    }

    /// Whether a value set with `setDeferringWrite` still owes its `defaults` write.
    public var hasDeferredWrites: Bool { !deferredWrites.isEmpty }

    /// Writes every value `setDeferringWrite` owes, as it is now.
    public func writeDeferred() {
        let owed = deferredWrites
        deferredWrites = [:]
        for write in owed.values { write() }
    }

    /// Drives the "changed from default" dot and per-row "Reset to Default".
    public func isDefault<V>(_ key: SettingKey<V>) -> Bool { self[key] == key.defaultValue }
    /// Restores the default of one key.
    public func reset<V>(_ key: SettingKey<V>) { self[key] = key.defaultValue }
    /// "Reset ‹Pane›…": every key of a namespace.
    public func reset(namespace: SettingsNamespace) { reset(prefix: Self.keyPrefix + namespace.rawValue + ".") }
    /// "Reset All Settings…" (EngineRecords are restored by the caller: they are records, not settings).
    public func resetAll() { reset(prefix: Self.keyPrefix) }

    /// The ids of the keys stored in `defaults` ("displays.linkLevels"): setting a default removes a key, so these are
    /// the settings that differ from their defaults. Names only, never values (diagnostics `nonDefaultSettings`,
    /// ARCHITECTURE.md §8.4); launch-argument seeds and the settings revision are not listed. Read-only.
    public func storedKeyIDs() -> [String] {
        let arguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        return defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(Self.keyPrefix) && $0 != Self.revisionKey && arguments[$0] == nil }
            .map { String($0.dropFirst(Self.keyPrefix.count)) }
            .sorted()
    }

    /// Opaque copy of every persisted key: taken before "Reset All" so Undo can restore it.
    public nonisolated struct Snapshot: Sendable { fileprivate let values: [String: Data] }
    /// Every persisted key (the settings revision included), for Undo of "Reset All".
    public func snapshot() -> Snapshot {
        var values: [String: Data] = [:]
        for (key, value) in defaults.dictionaryRepresentation() where key.hasPrefix(Self.keyPrefix) {
            if let data = value as? Data { values[key] = data }
        }
        return Snapshot(values: values)
    }
    /// Replaces every key with `snapshot` and updates the live values (Undo of "Reset All").
    public func restore(_ snapshot: Snapshot) {
        deferredWrites = [:]
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(Self.keyPrefix) && key != Self.revisionKey {
            defaults.removeObject(forKey: key)
        }
        for (key, data) in snapshot.values { defaults.set(data, forKey: key) }
        for handler in reloadHandlers.values { handler() }
    }

    private func reset(prefix: String) {
        deferredWrites = deferredWrites.filter { !(Self.keyPrefix + $0.key).hasPrefix(prefix) }
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) && key != Self.revisionKey {
            defaults.removeObject(forKey: key)
        }
        for (id, handler) in reloadHandlers where (Self.keyPrefix + id).hasPrefix(prefix) { handler() }
    }

    private func box<V>(_ key: SettingKey<V>) -> SettingBox<V> {
        if let b = boxes[key.id] as? SettingBox<V> { return b }
        let b = SettingBox(load(key))
        boxes[key.id] = b
        reloadHandlers[key.id] = { [weak self, weak b] in
            guard let self, let b else { return }
            let v = self.load(key)
            if b.value != v { b.value = v }
        }
        return b
    }

    /// Writes `value` to `defaults`; the default removes the key.
    private func write<V>(_ key: SettingKey<V>, _ value: V) {
        if value == key.defaultValue {
            defaults.removeObject(forKey: Self.keyPrefix + key.id)
        } else if let data = try? encoder.encode(value) {
            defaults.set(data, forKey: Self.keyPrefix + key.id)
        }
    }

    /// The persisted value, or the default (undecodable data is logged and ignored).
    private func load<V>(_ key: SettingKey<V>) -> V {
        guard let data = defaults.data(forKey: Self.keyPrefix + key.id) else { return key.defaultValue }
        if let v = try? decoder.decode(V.self, from: data) { return v }
        Log.logger(.settings).error("undecodable value for \(key.id, privacy: .public); using default")
        return key.defaultValue
    }
}
