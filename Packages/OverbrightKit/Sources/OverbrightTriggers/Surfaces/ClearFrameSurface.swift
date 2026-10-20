// OverbrightTriggers/Surfaces/ClearFrameSurface.swift — a layer that shows one clear-only frame per present: the
// content of T2/T3. ARCHITECTURE.md §4.7. Thread: main.
//
// The seam lets the retry, keep-alive and release rules of `MetalClearTrigger` be tested with a scripted surface and
// `ManualTimeSource`, without a Metal device or a window on screen.
import QuartzCore

/// One clear-only frame source.
protocol ClearFrameSurface: AnyObject {
    /// The layer the window hosts.
    var layer: CALayer { get }
    /// Presents one frame cleared to `value` (extended linear sRGB); false when no drawable or encoder was available
    /// (for example while the window is not yet in the render tree).
    func presentFrame(_ value: Double) -> Bool
    /// macOS 26+: tags the drawables with `headroom`; nil or ≤ 1 untags them.
    func applyTag(_ headroom: Double?)
    /// Drops the device, the queue and the drawable pool so the driver can free its working set. Presents fail after.
    func release()
}
