// OverbrightCore/Ports/TriggerHandle.swift — one trigger window (implemented by OverbrightTriggers). ARCHITECTURE.md §3.6, §4.7.
// Contract rule (§10.0): a requirement added after WP0a lands only together with a default implementation in a
// protocol extension in this file.
import CoreGraphics

/// One trigger window on one display.
@MainActor public protocol TriggerHandle: AnyObject {
    /// The rung this window shows.
    var request: TriggerRequest { get }
    /// The window is occluded (shield, another window).
    var isOccluded: Bool { get }
    /// Called when occlusion changes.
    var onOcclusionChange: ((Bool) -> Void)? { get set }
    /// Called when AppKit moves the window to another screen (`NSWindow.didChangeScreenNotification`): the
    /// controller removes the trigger at once if the new screen is not its display (§4.3).
    var onScreenChange: ((CGDirectDisplayID?) -> Void)? { get set }
    /// Shows the pixel. T2/T3 retry the first present every 50 ms for up to 2 s; false = never presented.
    func present(_ pixel: TriggerPixel) async -> Bool
    /// Event-driven re-present (wake, unlock, occlusion → visible, screen parameters). Re-places the window.
    func represent()
    /// Re-tags in place (tag policy B, ARCHITECTURE.md §4.7). No-op for HLG strategies.
    func requestHeadroom(_ headroom: Double)
    /// Orders the window out and releases it.
    func remove()
}
