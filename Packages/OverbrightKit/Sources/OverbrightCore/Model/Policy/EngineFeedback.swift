// OverbrightCore/Model/Policy/EngineFeedback.swift — what a display controller tells the reducer. ARCHITECTURE.md §3.4.

/// Per-display state the engine feeds back into the reducer.
public nonisolated struct EngineFeedback: Hashable, Sendable {
    /// The display's trip, if any.
    public var trip: TripCause?
    /// The newest headroom reading.
    public var lastReading: HeadroomReading?
    /// Feedback; nothing tripped and no reading by default.
    public init(trip: TripCause? = nil, lastReading: HeadroomReading? = nil) { self.trip = trip; self.lastReading = lastReading }
}
