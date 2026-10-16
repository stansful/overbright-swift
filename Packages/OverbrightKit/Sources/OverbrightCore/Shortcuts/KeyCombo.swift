// OverbrightCore/Shortcuts/KeyCombo.swift — a key code plus modifiers (ported from Cranny). ARCHITECTURE.md §3.7.

/// A key code plus Carbon-independent modifier flags (ported from Cranny).
public nonisolated struct KeyCombo: Hashable, Codable, Sendable {
    /// Modifier flags, independent of Carbon and AppKit.
    public struct Modifiers: OptionSet, Hashable, Codable, Sendable {
        /// The bits.
        public let rawValue: UInt8
        /// Flags from their bits.
        public init(rawValue: UInt8) { self.rawValue = rawValue }
        /// ⌘.
        public static let command = Modifiers(rawValue: 1 << 0)
        /// ⌥.
        public static let option = Modifiers(rawValue: 1 << 1)
        /// ⌃.
        public static let control = Modifiers(rawValue: 1 << 2)
        /// ⇧.
        public static let shift = Modifiers(rawValue: 1 << 3)
    }
    /// A `kVK_*` virtual key code (a key position, not a character).
    public var keyCode: UInt16
    /// The modifiers held.
    public var modifiers: Modifiers
    /// A combo.
    public init(keyCode: UInt16, modifiers: Modifiers) { self.keyCode = keyCode; self.modifiers = modifiers }
}
