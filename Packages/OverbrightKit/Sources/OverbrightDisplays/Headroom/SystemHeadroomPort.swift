// OverbrightDisplays/Headroom/SystemHeadroomPort.swift — the real `HeadroomPort`: the three EDR values of one display,
// read from a fresh NSScreen. ARCHITECTURE.md §3.6, §5.1, §8.1 rule 1, §10.4. Thread: main (NSScreen).
// Read-only: reading these values requests no headroom. `NSScreen.screens` is fetched on every read, because NSScreen
// objects are replaced after a screen-parameters change and a cached one keeps its old potential.
import AppKit
import CoreGraphics
import OverbrightCore

/// Reads `maximum…ExtendedDynamicRangeColorComponentValue` of the NSScreen that belongs to a display.
public final class SystemHeadroomPort: HeadroomPort {
    private let time: any TimeSource

    /// Readings are stamped with `time.now`.
    public init(time: any TimeSource) { self.time = time }

    /// A fresh read of `display`'s own screen, stamped with its display ID; nil for a hardware-mirror member or a
    /// display without an NSScreen (`HeadroomSampler`).
    public func reading(for display: DisplayRef) -> HeadroomReading? {
        #if DEBUG
        dispatchPrecondition(condition: .onQueue(.main))
        #endif
        let screen = NSScreen.screens.first { $0.overbrightDisplayID == display.id }.map { screen in
            ScreenEDRValues(display: display.id,
                            current: Double(screen.maximumExtendedDynamicRangeColorComponentValue),
                            potential: Double(screen.maximumPotentialExtendedDynamicRangeColorComponentValue),
                            reference: Double(screen.maximumReferenceExtendedDynamicRangeColorComponentValue))
        }
        return HeadroomSampler.reading(for: display, screen: screen, mirrorsDisplay: CGDisplayMirrorsDisplay(display.id),
                                       time: time.now)
    }
}
