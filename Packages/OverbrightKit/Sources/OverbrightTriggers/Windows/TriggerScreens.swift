// OverbrightTriggers/Windows/TriggerScreens.swift — which screen belongs to a display, and which display a window is
// on. ARCHITECTURE.md §3.6 (`onScreenChange`), §4.7 (placement), §8.1 rule 1. Thread: main (NSScreen).
import AppKit
import CoreGraphics

/// Screen lookups for the window code. The real one reads `NSScreen` fresh on every call (screens are re-fetched
/// after every screen-parameters change); tests use fixed geometry.
protocol TriggerScreens: AnyObject {
    /// The geometry of `display`'s screen; nil when the display has no screen of its own (mirror member, gone).
    func geometry(of display: CGDirectDisplayID) -> ScreenGeometry?
    /// The display whose screen `window` is on now; nil when it is on none.
    func display(of window: NSWindow) -> CGDirectDisplayID?
}

/// `NSScreen`-backed lookups.
final class SystemTriggerScreens: TriggerScreens {
    /// The screen of `display`, read now.
    func geometry(of display: CGDirectDisplayID) -> ScreenGeometry? {
        #if DEBUG
        dispatchPrecondition(condition: .onQueue(.main))
        #endif
        guard let screen = NSScreen.screens.first(where: { Self.displayID(of: $0) == display }) else { return nil }
        return ScreenGeometry(frame: screen.frame, auxiliaryTopLeftArea: screen.auxiliaryTopLeftArea,
                              auxiliaryTopRightArea: screen.auxiliaryTopRightArea,
                              backingScaleFactor: screen.backingScaleFactor)
    }

    /// The display of `window.screen`.
    func display(of window: NSWindow) -> CGDirectDisplayID? {
        #if DEBUG
        dispatchPrecondition(condition: .onQueue(.main))
        #endif
        return window.screen.flatMap(Self.displayID(of:))
    }

    /// The CoreGraphics display ID of `screen` (`NSScreenNumber`); never a name (D8).
    static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
