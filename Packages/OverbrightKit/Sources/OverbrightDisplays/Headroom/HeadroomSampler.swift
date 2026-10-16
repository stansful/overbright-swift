// OverbrightDisplays/Headroom/HeadroomSampler.swift — turns one screen's EDR values into a `HeadroomReading`.
// ARCHITECTURE.md §3.2 (`HeadroomReading`), §3.6 (`HeadroomPort`: nil for a display without its own NSScreen), §5.1,
// §10.4. Pure, so the mirror and stamping rules are tested without NSScreen.
import CoreGraphics
import OverbrightCore

/// The three EDR values one NSScreen reported for its display.
nonisolated struct ScreenEDRValues: Hashable, Sendable {
    /// The screen's display (`NSScreenNumber`).
    var display: CGDirectDisplayID
    /// `maximumExtendedDynamicRangeColorComponentValue`.
    var current: Double
    /// `maximumPotentialExtendedDynamicRangeColorComponentValue`.
    var potential: Double
    /// `maximumReferenceExtendedDynamicRangeColorComponentValue`.
    var reference: Double
}

/// Builds readings.
nonisolated enum HeadroomSampler {
    /// The reading of `display` from `screen` (its own NSScreen, if any), stamped with the display's ID and `time`.
    /// Nil for a hardware-mirror member (`mirrorsDisplay` ≠ `kCGNullDirectDisplay`: the set's NSScreen belongs to the
    /// master, so its values would be another display's), for a display without a screen, for a screen of another
    /// display, and for non-finite values (a screen in transition).
    static func reading(for display: DisplayRef, screen: ScreenEDRValues?, mirrorsDisplay: CGDirectDisplayID,
                        time: MonotonicInstant) -> HeadroomReading? {
        guard mirrorsDisplay == kCGNullDirectDisplay, let screen, screen.display == display.id,
              screen.current.isFinite, screen.potential.isFinite, screen.reference.isFinite else { return nil }
        return HeadroomReading(display: display.id, current: screen.current, potential: screen.potential,
                               reference: screen.reference, time: time)
    }
}
