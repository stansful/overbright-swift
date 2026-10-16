// OverbrightCore/Ports/OverlayHandle.swift — one Compatibility-mode overlay (implemented by OverbrightTriggers).
// ARCHITECTURE.md §3.6, §7.5.
// Contract rule (§10.0): a requirement added after WP0a lands only together with a default implementation in a
// protocol extension in this file.
import CoreGraphics

/// Technique C: one full-screen multiply overlay per display (Compatibility mode).
@MainActor public protocol OverlayHandle: AnyObject {
    /// The overlay window is occluded.
    var isOccluded: Bool { get }
    /// Called when occlusion changes.
    var onOcclusionChange: ((Bool) -> Void)? { get set }
    /// Called when AppKit moves the window to another screen.
    var onScreenChange: ((CGDirectDisplayID?) -> Void)? { get set }
    /// `factor` < 1 dims without EDR; > 1 multiplies and requests at least `headroomRequest`.
    func setFactor(_ factor: Double, headroomRequest: Double) throws
    /// Event-driven re-present.
    func represent()
    /// Orders the overlay out and releases it.
    func remove()
}
