// OverbrightCore/Model/Policy/TripCause.swift — why the engine stopped a display on its own. ARCHITECTURE.md §3.4, §4.3.

/// Why the engine stopped a display on its own (fed back into the reducer so the UI can say so).
/// Only `headroomNeverArrived` is retried automatically (wake, unlock, reconfiguration, potential change); the
/// others clear only on Try Again / Continue Anyway, or when the attributed app terminates (§4.3).
public nonisolated enum TripCause: Hashable, Sendable {
    /// Flicker-safety detector (D5).
    case oscillation
    /// 3 repairs in 6 s, or > 2 unexplained base adoptions in 60 s.
    case repairBudgetExceeded
    /// An identified app changed this display's table.
    case attributedDrift(ConflictingApp)
    /// Ladder exhausted / gate timed out (D6).
    case headroomNeverArrived
    /// Session-level residue that rescue could not clear (D7).
    case foreignTableAtLaunch
}
