// OverbrightCore/Model/Displays/HeadroomReading.swift — the three NSScreen EDR values of one display.
// ARCHITECTURE.md §3.2, §5.1, §5.4.
import CoreGraphics

/// The three NSScreen EDR values of ONE display, read on the main actor, stamped with monotonic time.
public nonisolated struct HeadroomReading: Hashable, Sendable {
    /// The display the NSScreen belongs to. `TableWriter` refuses a reading whose display differs from the write target.
    public var display: CGDirectDisplayID
    /// `maximumExtendedDynamicRangeColorComponentValue` (current, granted headroom H).
    public var current: Double
    /// `maximumPotentialExtendedDynamicRangeColorComponentValue` (≈ preset peak ÷ 100 nits).
    public var potential: Double
    /// `maximumReferenceExtendedDynamicRangeColorComponentValue` (> 0 only in reference modes).
    public var reference: Double
    /// When it was read (`TimeSource.now`); `TableWriter` refuses readings older than 150 ms.
    public var time: MonotonicInstant
    /// A reading of `display` taken at `time`.
    public init(display: CGDirectDisplayID, current: Double, potential: Double, reference: Double,
                time: MonotonicInstant) {
        self.display = display; self.current = current; self.potential = potential; self.reference = reference
        self.time = time
    }
}
