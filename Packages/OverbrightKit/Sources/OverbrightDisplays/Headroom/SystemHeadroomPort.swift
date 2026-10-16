// OverbrightDisplays/Headroom/SystemHeadroomPort.swift — the real `HeadroomPort`: the three EDR values of one display,
// read from a fresh NSScreen. ARCHITECTURE.md §3.6, §5.1, §8.1 rule 1, §10.4. Thread: main (NSScreen).
// Seeded by WP0a (read-only; reading these values requests no headroom); owned by WP2 afterwards.
import AppKit
import CoreGraphics
import OverbrightCore

/// Reads `maximum…ExtendedDynamicRangeColorComponentValue` of the NSScreen that belongs to a display.
public final class SystemHeadroomPort: HeadroomPort {
    private let time: any TimeSource

    /// Readings are stamped with `time.now`.
    public init(time: any TimeSource) { self.time = time }

    /// A fresh read of `display`'s screen; nil when the display has no NSScreen of its own (mirror member, gone).
    public func reading(for display: DisplayRef) -> HeadroomReading? {
        guard let screen = NSScreen.screens.first(where: { $0.overbrightDisplayID == display.id }) else { return nil }
        return HeadroomReading(display: display.id,
                               current: Double(screen.maximumExtendedDynamicRangeColorComponentValue),
                               potential: Double(screen.maximumPotentialExtendedDynamicRangeColorComponentValue),
                               reference: Double(screen.maximumReferenceExtendedDynamicRangeColorComponentValue),
                               time: time.now)
    }
}

public extension NSScreen {
    /// The CoreGraphics display ID of this screen (`NSScreenNumber`).
    var overbrightDisplayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
