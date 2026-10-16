// OverbrightCore/Model/Engine/CalibrationAbortReason.swift — why a calibration ended early. ARCHITECTURE.md §3.6;
// DESIGN.md §9. Added through the contract lane by WP5 (§10.0).

/// Why a calibration session ended early (DESIGN.md §9: Esc, any lock, occlusion, a headroom drop, 60 s). The
/// display is back at Standard in every case.
public nonisolated enum CalibrationAbortReason: String, Hashable, Sendable, CaseIterable {
    /// Esc, Stop, or the calibration window closed.
    case cancelled
    /// No trigger made macOS grant extra range on this display.
    case noExtraRange
    /// The grant fell during the test (brightness keys, heat, another app's HDR content leaving).
    case headroomDropped
    /// Lock, screensaver, sleep, or another session on the console.
    case shielded
    /// The calibration window or the trigger was hidden.
    case occluded
    /// The display was disconnected.
    case displayGone
    /// The sweep ran for its 60 s limit.
    case timeLimit
    /// The interlock refused a factor (stale or missing reading).
    case writeRefused
}
