// OverbrightDisplays/Headroom/NSScreen+DisplayID.swift — the CoreGraphics display of an NSScreen. ARCHITECTURE.md
// §3.6, §10.4. Thread: main (NSScreen). `NSScreen.cgDirectDisplayID` is macOS 26+, so the device description is read.
import AppKit
import CoreGraphics

public extension NSScreen {
    /// The CoreGraphics display ID of this screen (`NSScreenNumber`).
    var overbrightDisplayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
