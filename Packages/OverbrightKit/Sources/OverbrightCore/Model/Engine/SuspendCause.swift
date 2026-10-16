// OverbrightCore/Model/Engine/SuspendCause.swift — why a display is suspended. ARCHITECTURE.md §3.5, §4.3.

/// Why a display is in `EnginePhase.suspended`.
public nonisolated enum SuspendCause: Hashable, Sendable {
    /// Lock, screensaver, sleep or another session.
    case shielded
    /// The policy asked for neutral while a trigger lingers.
    case policy
    /// The trigger window is occluded.
    case occluded
    /// The display sleeps.
    case displayAsleep
    /// A reconfiguration is in progress, or a window moved to another screen.
    case reconfiguring
    /// The hang watchdog fired.
    case hungMainThread
    /// Our session is not on the console (D27).
    case notOnConsole
}
