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
