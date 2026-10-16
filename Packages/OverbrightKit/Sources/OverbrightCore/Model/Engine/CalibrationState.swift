// OverbrightCore/Model/Engine/CalibrationState.swift — where a running calibration is. ARCHITECTURE.md §3.6, §5.2;
// DESIGN.md §9. Added through the contract lane by WP5 (§10.0), so the calibration window, which sees only
// `CalibrationSession`, can show the right step.

/// Where a calibration session is (DESIGN.md §9). The window shows the matching step; the session owns every write.
public nonisolated enum CalibrationState: Hashable, Sendable {
    /// Returning the display to Standard, showing a trigger and waiting until macOS grants extra range.
    case preparing
    /// Extra range is there: the comparison (step 1) and the sweep (step 2) can run.
    case ready
    /// Step 2 raises the factor every 0.4 s; `CalibrationSession.isSweepPausedAtLimit` while it waits at the pause.
    case sweeping
    /// The sweep ended and the display is back at Standard. `mergeFactor` is the factor at which Space was pressed
    /// (nil: never, the sweep reached its end); `needsConfirmation`: the merge was near the linear prediction, so
    /// step 3 asks before anything can record `.linear`.
    case swept(mergeFactor: Double?, needsConfirmation: Bool)
    /// Step 3's frame is on screen (2 s at the linear-domain Peak factor).
    case confirming
    /// Ended early; the display is back at Standard. `finish(brighter:)` still returns what was measured.
    case aborted(CalibrationAbortReason)
    /// `finish(brighter:)` returned; the session is over.
    case finished
}
