// OverbrightBoost/Engine/SDRWhiteSource.swift — the SDR white the engine trusts, if any. ARCHITECTURE.md §5.5
// (colorimeter record; an external's HDR-mode frame average; the built-in backlight value only after H-N1), §5.6 (the
// outdoor row), D5. Pure and nonisolated: nits are never shown or used without one of these sources.
import OverbrightCore
import OverbrightPolicy

/// Picks the trusted SDR white of one display.
nonisolated enum SDRWhiteSource {
    /// Whether the built-in backlight's `BrightnessMilliNits` tracks SDR white while EDR is active (H-N1). Until the
    /// hardware session says so it is never used, and `DisplayFacts` carries no such value yet.
    static let trustsPanelReported = false
    /// A colorimeter value is SDR white only while the headroom stays within this fraction of the headroom it was
    /// measured with. macOS moves SDR white with the brightness and the ambient light (outdoors it raises it to about
    /// 1000 nits), and H = grant ÷ SDR white moves with it, so a different H means a different SDR white: the value no
    /// longer holds and the live worst-case Safe bound applies again (§5.6: "the same with a trusted SDR estimate").
    static let colorimeterHeadroomTolerance = 0.05

    /// A colorimeter value from a valid calibration record for the current mechanism while `reading` shows the same SDR
    /// white as the calibration did, else an external's HDR-mode frame average (`DisplayAttributes` MaxFrameAverage,
    /// matched WindowServer's SDR value on the measured OLED).
    static func estimate(facts: DisplayFacts, preferences: DisplayPreferences, mechanism: Mechanism,
                         machine: MachineIdentity, reading: HeadroomReading?) -> SDRWhiteEstimate? {
        if let record = preferences.calibration, let nits = record.measuredSDRWhiteNits, nits > 0,
           record.mechanism == mechanism, record.osBuild == machine.osBuild,
           let reading, abs(reading.potential - record.potentialAtTest) <= 0.05 * record.potentialAtTest,
           holds(measuredAt: record.headroomAtTest, reading: reading) {
            return SDRWhiteEstimate(nits: nits, source: .colorimeter)
        }
        if !facts.isBuiltIn, facts.supportsPQ == true, let average = facts.panelFrameAverageNits, average > 0,
           let potential = reading?.potential, potential > 1.01 {
            return SDRWhiteEstimate(nits: average, source: .hdrFrameAverage)
        }
        return nil
    }

    /// Whether a colorimeter value measured with headroom `measuredAt` still holds with `reading` (nil: it does not).
    static func holds(measuredAt: Double, reading: HeadroomReading?) -> Bool {
        guard let reading, measuredAt > 0 else { return false }
        return abs(reading.current - measuredAt) <= colorimeterHeadroomTolerance * measuredAt
    }
}
