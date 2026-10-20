// OverbrightPolicyTests/ReadoutValuesTests.swift — the pure numbers behind a card's readout (DESIGN.md §5.6): state,
// applied and asked gains, nits only with a trusted SDR white and a valid calibration, the shown preset at the level,
// the estimate flag and the dim percentage. ARCHITECTURE.md §3.10, §5.5, §6.2.
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightPolicy

@Suite struct ReadoutValuesTests {
    private typealias T = PolicyTestInputs
    private let white = SDRWhiteEstimate(nits: 600, source: .colorimeter)

    private func decision(_ level: LevelPosition, calibrated: Bool = false, display: FixtureDisplay = T.builtIn,
                          boostEnabled: Bool? = nil) -> DisplayDecision? {
        let record = calibrated ? T.record(.encoded, potential: display.headroom.potential) : nil
        let input = T.input([T.display(display, level: level, boostEnabled: boostEnabled, calibration: record)])
        return BoostPolicy.reduce(input).displays[display.key]
    }
    private func status(_ decision: DisplayDecision?, applied: Double, phase: EnginePhase = .boosted,
                        sdrWhite: SDRWhiteEstimate? = nil) -> DisplayStatus {
        DisplayStatus(key: T.builtIn.key, name: "Built-in Display", phase: phase, decision: decision, appliedGain: applied,
                      appliedFactor: FactorMath.tableFactor(forLightGain: applied, domain: .encoded), strategy: nil,
                      lastReading: nil, sdrWhite: sdrWhite)
    }
    private func values(_ status: DisplayStatus, on: Bool = true) -> ReadoutValues {
        Readout.values(for: status, isMasterOn: on)
    }

    @Test func offStandardAndPreparing() {
        let brightRoom = decision(LevelPreset.brightRoom.position)
        let off = values(status(brightRoom, applied: 1, phase: .idle), on: false)
        #expect(off.state == .off && off.preset == nil && off.requestedGain == nil && off.nits == nil && off.dimPercent == nil)
        for phase in [EnginePhase.arming(rung: 0), .gating(rung: 2)] {
            #expect(values(status(brightRoom, applied: 1, phase: phase)).state == .preparing)
        }
        for applied in [1.0, 1.004, 0.996] {
            let standard = values(status(decision(.standard), applied: applied, phase: .idle))
            #expect(standard.state == .standard && standard.preset == nil && standard.dimPercent == nil)
        }
        // A display stopped by a guard or a trip shows Standard; the chip says why.
        #expect(values(status(brightRoom, applied: 1, phase: .failed(.headroomNeverArrived))).state == .standard)
    }

    /// "Bright room · ≈ ×1.29" before calibration, "Bright room · ×1.29" after, "· ≈ 775 nits" with a trusted SDR white.
    @Test func boostingAtAPreset() {
        let uncalibrated = values(status(decision(LevelPreset.brightRoom.position), applied: 1.291))
        #expect(uncalibrated.state == .boost && uncalibrated.preset == .brightRoom && uncalibrated.isEstimate)
        #expect(uncalibrated.appliedGain == 1.291 && uncalibrated.requestedGain == nil && uncalibrated.nits == nil)
        let calibrated = values(status(decision(LevelPreset.brightRoom.position, calibrated: true), applied: 1.291))
        #expect(!calibrated.isEstimate && calibrated.nits == nil)                     // no trusted SDR white
        let nits = values(status(decision(LevelPreset.brightRoom.position, calibrated: true), applied: 1.291,
                                 sdrWhite: white))
        #expect(abs((nits.nits ?? 0) - 774.6) < 0.01)
        // A trusted SDR white without a valid calibration shows no nits (the multiplier is only an estimate).
        let estimate = values(status(decision(LevelPreset.brightRoom.position), applied: 1.291, sdrWhite: white))
        #expect(estimate.nits == nil && estimate.isEstimate)
        // Between presets: no preset name.
        #expect(values(status(decision(LevelPosition(0.6)), applied: 1.359)).preset == nil)
        #expect(values(status(decision(LevelPreset.max.position), applied: 1.667)).preset == .max)
    }

    /// "×1.21 · asked ×1.47": only while steadily boosted below the request, and then without a preset name.
    @Test func limitedBelowTheRequest() {
        let sunlight = decision(LevelPreset.sunlight.position)
        let limited = values(status(sunlight, applied: 1.21))
        #expect(abs((limited.requestedGain ?? 0) - 1.467) < 0.0005 && limited.preset == nil && limited.state == .boost)
        let ramping = values(status(sunlight, applied: 1.21, phase: .ramping))
        #expect(ramping.requestedGain == nil && ramping.preset == .sunlight)
        let atTarget = values(status(sunlight, applied: 1.4665))
        #expect(atTarget.requestedGain == nil && atTarget.preset == .sunlight)
    }

    /// A preset hidden on this display (§5.3) is never named: the MSI OLED in Safe shows only Bright room and Max.
    @Test func hiddenPresetsAreNeverNamed() {
        let indoor = decision(LevelPreset.indoor.position, display: T.msi, boostEnabled: true)
        #expect(values(status(indoor, applied: 1.068)).preset == nil)
        let brightRoom = decision(LevelPreset.brightRoom.position, display: T.msi, boostEnabled: true)
        #expect(values(status(brightRoom, applied: 1.140)).preset == .brightRoom)
        #expect(values(status(nil, applied: 1.291)).preset == nil)                  // no decision yet
        #expect(values(status(nil, applied: 1.291)).isEstimate)
    }

    /// The preset follows the level the reducer used (a linked level or the Focus filter's), not the stored one.
    @Test func thePresetFollowsTheEffectiveLevel() {
        let input = T.input([T.display(level: .standard)],
                            settings: PolicySettings(linkLevels: true, linkedLevel: LevelPreset.sunlight.position))
        let linked = BoostPolicy.reduce(input).builtIn
        #expect(values(status(linked, applied: 1.467)).preset == .sunlight)
    }

    /// "Dimmed · 25 %": light in percent of Standard, 2…99.
    @Test func dimPercent() {
        let dim = decision(LevelPosition(-0.66))
        for (applied, percent) in [(0.25, 25), (0.5, 50), (0.02, 2), (0.015, 2), (0.993, 99), (0.1, 10)] {
            let readout = values(status(dim, applied: applied, phase: .dimmed))
            #expect(readout.state == .dim && readout.dimPercent == percent, "\(applied)")
            #expect(readout.preset == nil && readout.nits == nil && readout.requestedGain == nil)
        }
    }
}
