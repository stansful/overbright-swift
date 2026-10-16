// OverbrightTriggers/Windows/TriggerScreens.swift — which screen belongs to a display, and which display a window is
// on. ARCHITECTURE.md §3.6 (`onScreenChange`), §4.7 (placement), §8.1 rule 1. Thread: main (NSScreen).
import AppKit
import CoreGraphics

/// Screen lookups for the window code. The real one (`SystemTriggerScreens`) reads `NSScreen` fresh on every call
/// (screens are re-fetched after every screen-parameters change); tests use fixed geometry.
protocol TriggerScreens: AnyObject {
    /// The geometry of `display`'s screen; nil when the display has no screen of its own (mirror member, gone).
    func geometry(of display: CGDirectDisplayID) -> ScreenGeometry?
    /// The display whose screen `window` is on now; nil when it is on none.
    func display(of window: NSWindow) -> CGDirectDisplayID?
}
