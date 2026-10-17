// OverbrightCore/Model/Policy/EngineFeedback.swift — what a display controller tells the reducer. ARCHITECTURE.md §3.4.

/// Per-display state the engine feeds back into the reducer.
public nonisolated struct EngineFeedback: Hashable, Sendable {
    /// The display's trip, if any.
    public var trip: TripCause?
    /// The newest headroom reading.
    public var lastReading: HeadroomReading?
    /// The taper's reference the engine writes with (§5.4 `H_full`: the lowest ready headroom of this display and OS
    /// build, never above the seed `panelPeak ÷ sdrMax`), so the reducer reports the taper exactly when the writer
    /// applies it. nil: the reducer uses the seed (no controller, or nothing known yet). Added in WP14 through the
    /// contract lane.
    public var fullBrightnessHeadroom: Double?
    /// Feedback; nothing tripped, no reading and the seed reference by default.
    public init(trip: TripCause? = nil, lastReading: HeadroomReading? = nil, fullBrightnessHeadroom: Double? = nil) {
        self.trip = trip; self.lastReading = lastReading; self.fullBrightnessHeadroom = fullBrightnessHeadroom
    }
}
