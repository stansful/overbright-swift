// OverbrightCore/Model/Displays/DisplayVerdict.swift — the eligibility verdict of one display. ARCHITECTURE.md §3.2, D8.

/// What a display can do (D8), from Policy's `EligibilityClassifier`. Design owns the sentences.
public nonisolated enum DisplayVerdict: Hashable, Codable, Sendable {
    /// Transient potential < 1 or no reading yet: re-check later.
    case checking
    /// Boost possible. `safeGain`/`peakGain`: the slider tops at full brightness (Safe may be nil: no Safe boost).
    case supported(safeGain: Double?, peakGain: Double)
    /// Even Peak adds < 10 % at full brightness.
    case noGainAtFullBrightness(peakGain: Double)
    /// The preset's peak is well below the panel's: another preset would allow more.
    case presetLimits(presetPeakNits: Double, panelPeakNits: Double)
    /// External with PQ support, HDR off in macOS.
    case turnOnHDR
    /// Built-in / XDR panel in an SDR preset.
    case switchPreset
    /// Reference > 0.
    case referencePreset
    /// Potential ≤ 2.
    case lcdClass
    /// Hardware-mirror member without its own NSScreen: dim only.
    case mirrored
    /// Sidecar, AirPlay, placeholder.
    case virtualDisplay
    /// The display has no transfer table.
    case noGammaTable
    /// SDR external without PQ.
    case notHDR
    /// Verdicts on which the boost half may be used.
    public var allowsBoost: Bool {
        switch self { case .supported, .noGainAtFullBrightness, .presetLimits: true; default: false }
    }
    /// Dimming needs only a transfer table (or the overlay), never headroom or the per-display boost switch.
    public var allowsDim: Bool {
        switch self { case .virtualDisplay, .noGammaTable, .referencePreset, .checking: false; default: true }
    }
}
