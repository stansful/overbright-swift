// OverbrightTriggers/Windows/SystemTriggerScreens.swift — `TriggerScreens` over `NSScreen`, read fresh on every call.
// ARCHITECTURE.md §3.6 (`onScreenChange`), §4.7 (placement), §8.1 rule 1, D8 (displays by ID, never by name).
// Thread: main (NSScreen).
import AppKit
import CoreGraphics

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
