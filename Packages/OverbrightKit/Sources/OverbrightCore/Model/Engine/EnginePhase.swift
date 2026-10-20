// OverbrightCore/Model/Engine/EnginePhase.swift — the per-display engine phase. ARCHITECTURE.md §3.5, §4.2.

/// Per-display engine phase (ARCHITECTURE.md §4.2).
public nonisolated enum EnginePhase: Hashable, Sendable {
    /// Neutral table, no trigger, zero work.
    case idle
    /// Table below 1, no headroom needed.
    case dimmed
    /// Trigger rung shown, waiting for the first headroom movement.
    case arming(rung: Int)
    /// Headroom moved (or was already held); waiting for a stable value (D6).
    case gating(rung: Int)
    /// Table factor moving towards the target.
    case ramping
    /// Steady; drift watchdog every 2 s.
    case boosted
    /// Neutral written; trigger kept ≤ 10 s, then removed.
    case suspended(SuspendCause)
    /// Neutral, no trigger, reason shown (§4.3 says which trips auto-retry).
    case failed(TripCause)
    /// Ramp down → baseline → remove trigger.
    case disarming
}
