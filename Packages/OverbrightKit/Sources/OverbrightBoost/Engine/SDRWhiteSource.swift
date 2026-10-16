// OverbrightBoost/Engine/SDRWhiteSource.swift — the SDR white the engine trusts, if any. ARCHITECTURE.md §5.5
// (colorimeter record; an external's HDR-mode frame average; the built-in backlight value only after H-N1), D5.
// Pure and nonisolated: nits are never shown or used without one of these sources.
import OverbrightCore
import OverbrightPolicy

/// Picks the trusted SDR white of one display.
nonisolated enum SDRWhiteSource {
    /// Whether the built-in backlight's `BrightnessMilliNits` tracks SDR white while EDR is active (H-N1). Until the
    /// hardware session says so it is never used, and `DisplayFacts` carries no such value yet.
    static let trustsPanelReported = false

    /// A colorimeter value from a valid calibration record for the current mechanism, else an external's HDR-mode
    /// frame average (`DisplayAttributes` MaxFrameAverage, matched WindowServer's SDR value on the measured OLED;
    /// never on an Apple XDR external, where it is the full-screen sustained HDR level: Policy's
    /// `GainCeiling.frameAverageSDRWhite`).
    static func estimate(facts: DisplayFacts, preferences: DisplayPreferences, mechanism: Mechanism,
                         machine: MachineIdentity, reading: HeadroomReading?) -> SDRWhiteEstimate? {
        if let record = preferences.calibration, let nits = record.measuredSDRWhiteNits, nits > 0,
           record.mechanism == mechanism, record.osBuild == machine.osBuild,
           let potential = reading?.potential, abs(potential - record.potentialAtTest) <= 0.05 * record.potentialAtTest {
            return SDRWhiteEstimate(nits: nits, source: .colorimeter)
        }
        if facts.supportsPQ == true, let average = GainCeiling.frameAverageSDRWhite(facts: facts),
           let potential = reading?.potential, potential > 1.01 {
            return SDRWhiteEstimate(nits: average, source: .hdrFrameAverage)
        }
        return nil
    }
}
