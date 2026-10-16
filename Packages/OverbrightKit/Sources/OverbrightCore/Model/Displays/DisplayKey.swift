// OverbrightCore/Model/Displays/DisplayKey.swift — the persistent identity of a display (its CoreGraphics UUID).
// ARCHITECTURE.md §3.2, §3.6 (dictionary-keyed settings), D8.
import ColorSync
import CoreGraphics
import Foundation

/// Stable identity of a display: the `CGDisplayCreateUUIDFromDisplayID` string. Persisted; never a name.
public nonisolated struct DisplayKey: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    /// The UUID string, upper-cased.
    public let rawValue: String
    /// A key from a UUID string (upper-cased, so keys from any source compare equal).
    public init(rawValue: String) { self.rawValue = rawValue.uppercased() }
    /// Raw-string order (stable sorting in diagnostics and tests).
    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
    /// The UUID string.
    public var description: String { rawValue }
    /// The one way every module derives a key (read-only CoreGraphics call). Nil for IDs macOS no longer knows.
    public static func of(_ id: CGDirectDisplayID) -> DisplayKey? {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue(),
              let string = CFUUIDCreateString(nil, uuid) as String? else { return nil }
        return DisplayKey(rawValue: string)
    }
}

// MARK: - Coding keys for dictionary-keyed settings (JSON objects, not arrays)

extension DisplayKey: CodingKeyRepresentable {
    /// The UUID string as a JSON object key (`DisplaySettings.perDisplay`).
    public var codingKey: any CodingKey { Key(stringValue: rawValue) }
    /// A key read back from a JSON object key.
    public init?<T: CodingKey>(codingKey: T) { self.init(rawValue: codingKey.stringValue) }
    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }
}
