// OverbrightBoost/Engine/WriteParameters.swift — what a controller needs besides its decision to write and arm.
// ARCHITECTURE.md §4.1 (the engine flattens settings and the snapshot), §5.4 (`liveCap` inputs), §4.7 (override), D27.
import OverbrightCore

/// The per-display inputs of the interlock, the ramps and the ladder that come from settings and the system snapshot
/// rather than from the reducer's decision. Built by `BoostEngine` on every reduction.
nonisolated struct WriteParameters: Hashable, Sendable {
    /// Safe or Peak (the live Safe bound applies in Safe).
    var capMode: CapMode = .safe
    /// OLED by class or by the user's override (black rungs only, the OLED Safe cap).
    var isOLED = false
    /// A trusted SDR white (skips the live Safe bound).
    var sdrWhite: SDRWhiteEstimate?
    /// "Add extra brightness only near full brightness" (the taper).
    var taper = true
    /// Reduce Motion: ramps take 160 ms.
    var reduceMotion = false
    /// Advanced ▸ Trigger method.
    var triggerOverride: TriggerStrategy?
    /// macOS asks apps to suppress HDR: keep the rung, never escalate, pause the timeouts.
    var isHDRSuppressed = false
    /// The session is on the console; false → no write at all (D27).
    var isSessionActive = true
}
