// OverbrightCore/Model/Displays/DisplayRef.swift — a connected display: persistent key plus transient ID. ARCHITECTURE.md §3.2.
import CoreGraphics

/// A connected display: its persistent key plus the transient CoreGraphics ID (valid until reconfiguration).
public nonisolated struct DisplayRef: Hashable, Sendable {
    /// The persistent identity.
    public var key: DisplayKey
    /// The CoreGraphics display ID; changes across reconfigurations.
    public var id: CGDirectDisplayID
    /// A reference to the display `id`, known as `key`.
    public init(key: DisplayKey, id: CGDirectDisplayID) { self.key = key; self.id = id }
}
