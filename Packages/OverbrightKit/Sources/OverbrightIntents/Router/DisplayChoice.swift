// OverbrightIntents/Router/DisplayChoice.swift — a display as the Shortcuts app offers it. ARCHITECTURE.md §7.7
// (`DisplayEntity` + `DisplayQuery` keyed by `DisplayKey`, names for presentation only); D8, D18.
import OverbrightCore

/// One display for the app target's `DisplayQuery`: its persistent key and, while it is online, its name. The name is
/// for presentation only; nothing compares it (D8).
public nonisolated struct DisplayChoice: Hashable, Sendable {
    /// The display's key (its CoreGraphics UUID).
    public var key: DisplayKey
    /// `NSScreen.localizedName` while the display is online; nil when it is not connected.
    public var name: String?

    /// A choice.
    public init(key: DisplayKey, name: String?) { self.key = key; self.name = name }
}
