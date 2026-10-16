// OverbrightCore/Model/Policy/BoostTarget.swift — what one display should show. ARCHITECTURE.md §3.4, §5.4.

/// What one display should show. Gains are LIGHT gains (multiples of SDR white), never table factors.
public nonisolated enum BoostTarget: Hashable, Sendable {
    /// Standard: the baseline table, no trigger.
    case neutral
    /// Light factor below 1 (dim below the macOS minimum). Needs no headroom.
    case dim(light: Double)
    /// Requested light gain after every static cap; the engine still applies `GainCeiling.liveCap` at write time.
    case boost(gain: Double)
}
