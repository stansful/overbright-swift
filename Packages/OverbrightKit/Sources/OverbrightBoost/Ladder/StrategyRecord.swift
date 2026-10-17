// OverbrightBoost/Ladder/StrategyRecord.swift — what the strategy cache keeps per display and OS build.
// ARCHITECTURE.md §4.7 (cache and the two-arm replacement rule), §5.4 (the lowest ready headroom), §8.2.
import OverbrightCore

/// The learned trigger and headroom facts of one display on one OS build.
public nonisolated struct StrategyRecord: Hashable, Codable, Sendable {
    /// The winning rung's number (§4.7); nil until a normal arm became ready.
    public var rung: Int?
    /// Separate normal arms, outside the wake/unlock quarantine, in which the cached rung failed since it last won.
    /// At two, a heavier winner replaces it.
    public var failures: Int
    /// The lowest headroom at which a gate became ready (the taper's full-brightness reference, §5.4).
    public var lowestReadyHeadroom: Double?
    /// The highest headroom macOS granted while the display boosted (DESIGN.md §12.1's "macOS allowed up to …"; WP14).
    /// Optional, so a file written before it decodes unchanged.
    public var highestGrantedHeadroom: Double?

    /// A record.
    public init(rung: Int? = nil, failures: Int = 0, lowestReadyHeadroom: Double? = nil,
                highestGrantedHeadroom: Double? = nil) {
        self.rung = rung; self.failures = failures; self.lowestReadyHeadroom = lowestReadyHeadroom
        self.highestGrantedHeadroom = highestGrantedHeadroom
    }
}
