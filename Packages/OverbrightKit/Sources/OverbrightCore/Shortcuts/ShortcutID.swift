// OverbrightCore/Shortcuts/ShortcutID.swift — global shortcut identifiers. ARCHITECTURE.md §3.7, D17.

/// A global shortcut's persisted identifier ("boost.toggle"). Never rename one that shipped. None has a default
/// combination (D17): the user records one in Settings ▸ Shortcuts.
public nonisolated struct ShortcutID: Hashable, Codable, Sendable, CustomStringConvertible {
    /// The persisted string.
    public let rawValue: String
    /// An identifier from its raw string.
    public init(_ rawValue: String) { self.rawValue = rawValue }
    /// The raw string.
    public var description: String { rawValue }
    /// Turn on or off.
    public static let toggle = ShortcutID("boost.toggle")
    /// One step brighter.
    public static let brighter = ShortcutID("boost.brighter")
    /// One step down; never crosses Standard in one press.
    public static let lessBright = ShortcutID("boost.lessBright")
    /// Max.
    public static let max = ShortcutID("boost.max")
    /// Back to Standard: fast off, levels kept.
    public static let standard = ShortcutID("boost.standard")
    /// "Dim Below Minimum On or Off", all displays.
    public static let dimToggle = ShortcutID("boost.dimToggle")
    /// Fill Light on or off.
    public static let fillLight = ShortcutID("fillLight.toggle")
}

// MARK: - Coding keys for dictionary-keyed settings (JSON objects, not arrays)

extension ShortcutID: CodingKeyRepresentable {
    /// The raw string as a JSON object key (`ShortcutSettings.bindings`).
    public var codingKey: any CodingKey { Key(stringValue: rawValue) }
    /// An identifier read back from a JSON object key.
    public init?<T: CodingKey>(codingKey: T) { self.init(codingKey.stringValue) }
    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }
}
