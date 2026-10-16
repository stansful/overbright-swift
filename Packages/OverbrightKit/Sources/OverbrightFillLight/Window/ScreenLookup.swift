// OverbrightFillLight/Window/ScreenLookup.swift — NSScreen ⇄ display ID, never by name (D8). ARCHITECTURE.md §3.6
// (NSScreen objects are re-fetched after every screen-parameters change). Thread: main.
import AppKit
import CoreGraphics

/// Finds the `NSScreen` of a display by its `CGDirectDisplayID` (fetched fresh on every call).
enum ScreenLookup {
    /// The display ID of `screen` (`NSScreenNumber`).
    static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber).map { CGDirectDisplayID($0.uint32Value) }
    }

    /// The screen that shows display `id` now; nil for a mirror member or a display that went away.
    static func screen(for id: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { displayID(of: $0) == id }
    }
}
