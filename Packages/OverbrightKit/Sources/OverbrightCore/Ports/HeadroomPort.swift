// OverbrightCore/Ports/HeadroomPort.swift — NSScreen EDR reads (implemented by OverbrightDisplays). ARCHITECTURE.md §3.6, §5.1.
// Contract rule (§10.0): a requirement added after WP0a lands only together with a default implementation in a
// protocol extension in this file.

/// Reads the EDR values of one display on the main actor.
@MainActor public protocol HeadroomPort: AnyObject {
    /// Fresh NSScreen read for exactly this display (NSScreen objects are re-fetched after every screen-parameters
    /// change). Nil for a display without its own NSScreen (mirror member, gone).
    func reading(for display: DisplayRef) -> HeadroomReading?
}
