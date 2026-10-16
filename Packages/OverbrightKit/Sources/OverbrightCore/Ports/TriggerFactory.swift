// OverbrightCore/Ports/TriggerFactory.swift — makes triggers and overlays (implemented by OverbrightTriggers).
// ARCHITECTURE.md §3.6, §4.7, D24.
// Contract rule (§10.0): a requirement added after WP0a lands only together with a default implementation in a
// protocol extension in this file.

/// Makes trigger and overlay windows.
@MainActor public protocol TriggerFactory: AnyObject {
    /// Whether the strategy can run on this Mac and OS.
    func isAvailable(_ strategy: TriggerStrategy) -> Bool
    /// A trigger window for `request` on `display` (not yet presented).
    func makeTrigger(_ request: TriggerRequest, on display: DisplayRef) throws -> any TriggerHandle
    /// A Compatibility-mode overlay on `display` (factor 1 until set).
    func makeOverlay(on display: DisplayRef) throws -> any OverlayHandle
    /// Open trigger + overlay windows (diagnostics `triggerWindows`; smoke asserts 0).
    var openWindowCount: Int { get }
}
