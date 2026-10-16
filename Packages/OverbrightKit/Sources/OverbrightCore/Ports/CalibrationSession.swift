// OverbrightCore/Ports/CalibrationSession.swift — a running calibration (implemented by OverbrightBoost).
// ARCHITECTURE.md §3.6, §5.2; DESIGN.md §9.
// Contract rule (§10.0): a requirement added after WP0a lands only together with a default implementation in a
// protocol extension in this file.

/// A running calibration (DESIGN.md §9). The view drives it; the engine owns every table write.
/// Starting one returns every display to Standard first (triggers removed, neutral tables).
@MainActor public protocol CalibrationSession: AnyObject {
    /// The display under calibration.
    var display: DisplayKey { get }
    /// The table factor shown now.
    var currentFactor: Double { get }
    /// The headroom macOS grants now.
    var headroom: Double? { get }
    /// True while the sweep waits at 1.15 × the encoded prediction for "Keep Going" (DESIGN.md §9).
    var isSweepPausedAtLimit: Bool { get }
    /// "Did it get brighter?" (≤ 1 flip per 1.5 s).
    func showComparison(boosted: Bool)
    /// 1.00 → cap in 0.02 steps every 400 ms, black surround.
    func startSweep()
    /// Past the 1.15 × encoded-prediction pause.
    func continueSweep()
    /// Space: the 0.95 patch merged with white.
    func markMerged()
    /// Shows the patches for 2 s at the LINEAR-domain Peak factor; only "distinguishable" can record `.linear`.
    func showLinearConfirmation()
    /// The user's answer to the linear confirmation.
    func answerLinearConfirmation(distinguishable: Bool)
    /// A colorimeter reading of SDR white, or nil.
    func setMeasuredSDRWhite(nits: Double?)
    /// Ends the session and returns the record to store (nil when nothing was measured).
    func finish(brighter: Bool?) -> CalibrationRecord?
    /// Esc: neutral at once.
    func cancel()
    /// The step the session is in (DESIGN.md §9), so the window can show it. Added by WP5 through the contract lane.
    var state: CalibrationState { get }
}

extension CalibrationSession {
    /// A session that does not report its step is always ready (the §10.0 default for a requirement added after WP0a).
    public var state: CalibrationState { .ready }
}
