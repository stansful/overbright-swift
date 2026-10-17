// OverbrightBoostTests/Engine/RealPolicyTests.swift — the engine over WP1's `BoostPolicy.reduce` (the app's reducer)
// instead of the reference reducer: the class defaults, the Safe top, opt-in OLED, dimming without opt-in, guards,
// and the engine property test on a smaller budget. ARCHITECTURE.md §6.1, §9.1, §10.6 ("WP1's real Policy once
// merged").
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct RealPolicyTests {
    @Test func builtInXDRBoostsAtItsSafeLevel() async throws {
        let h = EngineHarness(decide: BoostPolicy.reduce)
        await h.start()
        #expect(await h.boost())
        let decision = try #require(h.displayStatus()?.decision)
        guard case .boost(let gain) = decision.target else {
            Issue.record("not a boost: \(decision.target)")
            return
        }
        #expect(gain > 1.2 && gain <= 1000.0 / 600 + 1e-9)               // Bright room within the Safe top
        #expect(h.interlockViolations().isEmpty && h.orderViolations.isEmpty)
        h.engine.step(.brighter, source: .shortcut)                       // the verdict's top drives steps
        #expect(h.engine.storedLevel(of: h.builtIn) > LevelPreset.brightRoom.position)
    }

    @Test func oledIsOptInButDimsWithoutIt() async throws {
        let h = EngineHarness(fixture: .mpg322uxHDROn, decide: BoostPolicy.reduce)
        let msi = DisplayFixture.Keys.mpg322ux
        await h.start()
        h.engine.setOn(true, source: .panel)
        await h.advance(.seconds(5))
        #expect(h.phase(msi) == .idle && h.triggers.made.isEmpty)
        #expect(h.displayStatus(msi)?.decision?.reasons.contains(.boostNotEnabled) == true)
        h.engine.setDimLight(0.5, for: msi, source: .panel)
        await h.advance(.milliseconds(400))
        #expect(h.phase(msi) == .dimmed)
    }

    @Test func lowPowerStopsTheBoostOnly() async throws {
        let h = EngineHarness(decide: BoostPolicy.reduce)
        await h.start()
        #expect(await h.boost())
        h.signals.snapshot.power = PowerState(source: .battery, batteryPercent: 80, isLowPowerMode: true)
        await h.advance(.seconds(1))
        #expect(h.phase() == .idle && h.everyTableAtBase)
        #expect(h.engine.status.lastChange?.kind == .automationStopped(.lowPowerMode))
        h.engine.setLevel(LevelPosition(-0.4), for: h.builtIn, source: .panel)
        await h.advance(.milliseconds(400))
        #expect(h.phase() == .dimmed)
    }

    /// A colorimeter value is SDR white only at the headroom it was measured with (§5.5). Indoors at that headroom
    /// Safe is exact (capNits ÷ 600 = ×1.667) and the readout has its nits; outdoors macOS raises SDR white to 1000 nits
    /// (H 1.6 at a full grant), the value no longer holds, and the live worst-case bound gives no Safe boost, the same as
    /// without the value (§5.6's outdoor row; C-BOOST-4).
    @Test func aColorimeterValueHoldsOnlyAtItsHeadroom() async throws {
        let h = EngineHarness(decide: BoostPolicy.reduce)
        let grant = 1600.0 / 600
        let potential = try #require(h.scripted.script(for: h.builtIn)?.potential)
        let record = CalibrationRecord(outcome: .encoded, mechanism: .table, mergeFactor: 1.61, estimatedExponent: 2.4,
                                       measuredSDRWhiteNits: 600, headroomAtTest: grant, potentialAtTest: potential,
                                       osBuild: h.fixture.machine.osBuild, measuredAt: Date())
        h.setPreferences { $0.calibration = record; $0.level = LevelPreset.max.position }
        await h.start()
        #expect(await h.boost())
        await h.advance(.seconds(1))
        let indoors = try #require(h.displayStatus())
        #expect(indoors.sdrWhite == SDRWhiteEstimate(nits: 600, source: .colorimeter))
        #expect(abs(indoors.appliedGain - 1000.0 / 600) < 0.005)
        h.scripted.setGrant(1.6, for: h.builtIn)                          // outdoors: SDR white 1000 nits
        h.signals.emit(.screenParametersChanged)
        await h.advance(.seconds(3))
        let outdoors = try #require(h.displayStatus())
        #expect(outdoors.sdrWhite == nil)
        #expect(outdoors.appliedGain <= 1 + 1e-9 && h.everyTableAtBase)  // 1000 × 1.6 ÷ 1600 = ×1.0
        #expect(outdoors.decision?.reasons.contains(.safeLimit) == true)
    }

    /// The chip names the taper exactly when the writer applies it: the reducer gets the controller's reference (the
    /// learned lowest ready H 1.6, below the seed 2.667), so at H 2.2 the decision says "Below full brightness" and the
    /// writer's limit agrees (C-BOOST-7).
    @Test func theTaperReasonFollowsTheWritersReference() async throws {
        let h = EngineHarness(decide: BoostPolicy.reduce)
        h.engine.strategyCache.learnReadyHeadroom(1.6, for: h.builtIn, osBuild: h.fixture.machine.osBuild)
        h.scripted.update(h.builtIn) { $0.grant = 2.2 }
        await h.start()
        #expect(await h.boost())
        await h.advance(.seconds(1))
        let status = try #require(h.displayStatus())
        #expect(h.controller()?.fullBrightnessHeadroom == 1.6)
        #expect(h.controller()?.appliedLimit == .nearFullBrightnessOnly)
        #expect(status.decision?.reasons.contains(.nearFullBrightnessOnly) == true)
        #expect(status.appliedGain < (status.decision?.requestedGain ?? 0) - 0.01)
        #expect(h.inputs.last?.displays.first?.feedback.fullBrightnessHeadroom == 1.6)
    }

    /// The largest grant seen while boosting is kept and published as the gain it allows (`lastGrant`, DESIGN.md
    /// §12.1's "macOS allowed up to …"; C-BOOST-25).
    @Test func theLargestGrantIsPublished() async throws {
        let h = EngineHarness(decide: BoostPolicy.reduce)
        await h.start()
        #expect(h.displayStatus()?.lastGrant == nil)
        #expect(await h.boost())
        let grant = 1600.0 / 600
        #expect(abs((h.displayStatus()?.lastGrant ?? 0) - FactorMath.headroomMargin * grant) < 0.01)
        let record = h.engine.strategyCache.record(for: h.builtIn, osBuild: h.fixture.machine.osBuild)
        #expect(abs((record?.highestGrantedHeadroom ?? 0) - grant) < 0.01)
    }

    /// The property test of EngineFuzzTests over the real reducer (1 000 sequences; the reference reducer runs 10 000).
    @Test func randomSequencesKeepTheInvariantsWithTheRealPolicy() async throws {
        var seeds = SeededGenerator(seed: 0x0B21_E7F2)
        let count = min(EngineFuzzTests.sequences, 1_000)
        var boosted = 0
        for _ in 0..<count {
            let seed = seeds.next()
            let outcome = await EngineFuzzTests().run(seed: seed, decide: BoostPolicy.reduce)
            if outcome.reachedBoosted { boosted += 1 }
            guard outcome.breaches.isEmpty else {
                Issue.record("seed \(seed): \(outcome.breaches.prefix(4))")
                return
            }
        }
        #expect(boosted > 0)
    }
}
