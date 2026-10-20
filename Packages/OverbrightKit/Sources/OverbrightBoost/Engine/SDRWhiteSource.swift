// OverbrightBoost/Engine/SDRWhiteSource.swift — the SDR white the engine trusts, if any. ARCHITECTURE.md §5.5
// (colorimeter record; an external's HDR-mode frame average), §5.6 (the outdoor row), D5. Pure and nonisolated: nits
// are never shown or used without one of these sources.
import OverbrightCore
import OverbrightPolicy

/// Picks the trusted SDR white of one display.
nonisolated enum SDRWhiteSource {
    /// A colorimeter value is SDR white only while the headroom stays within this fraction of the headroom it was
    /// measured with. macOS moves SDR white with the brightness and the ambient light (outdoors it raises it to about
    /// 1000 nits), and H = grant ÷ SDR white moves with it, so a different H means a different SDR white: the value no
    /// longer holds and the live worst-case Safe bound applies again (§5.6: "the same with a trusted SDR estimate").
    static let colorimeterHeadroomTolerance = 0.05

    /// A colorimeter value from a valid calibration record for the current mechanism while `reading` shows the same SDR
    /// white as the calibration did, else an external's HDR-mode frame average (`DisplayAttributes` MaxFrameAverage,
    /// matched WindowServer's SDR value on the measured OLED; never on an Apple XDR external, where it is the
    /// full-screen sustained HDR level: Policy's `GainCeiling.frameAverageSDRWhite`).
    static func estimate(facts: DisplayFacts, preferences: DisplayPreferences, mechanism: Mechanism,
                         machine: MachineIdentity, reading: HeadroomReading?) -> SDRWhiteEstimate? {
        if let record = preferences.calibration, let nits = record.measuredSDRWhiteNits, nits > 0,
           record.mechanism == mechanism, record.osBuild == machine.osBuild,
           let reading, abs(reading.potential - record.potentialAtTest) <= 0.05 * record.potentialAtTest,
           holds(measuredAt: record.headroomAtTest, reading: reading) {
            return SDRWhiteEstimate(nits: nits, source: .colorimeter)
        }
        if facts.supportsPQ == true, let average = GainCeiling.frameAverageSDRWhite(facts: facts),
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
