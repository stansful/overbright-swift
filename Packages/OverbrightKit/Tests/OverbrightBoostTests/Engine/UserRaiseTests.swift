// OverbrightBoostTests/Engine/UserRaiseTests.swift — raises (ARCHITECTURE.md §4.3, §5.7): a raise the user asks for
// applies at once as far as a reading taken now allows, then a 10 Hz poll burst of at most 3 s raises further as
// headroom arrives; a raise driven by headroom recovery (or by write parameters that change by themselves) waits for
// 1.5 s of stable headroom and ≥ 5 %.
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct UserRaiseTests {
    private let peakTop = 2.587

    /// Peak on the M4 Max with only 1.8 granted: Bright room holds, Max asks for more than macOS allows.
    private func limitedHarness() async -> EngineHarness {
        let h = EngineHarness(reducer: ReferenceReducer(top: peakTop))
        h.setPreferences { $0.capMode = .peak }
        h.settings[DisplaySettings.boostOnlyNearFullBrightness] = false
        h.scripted.update(h.builtIn) { $0.grant = 1.8 }
        await h.start()
        let boosted = await h.boost()
        #expect(boosted)
        await h.advance(.seconds(1))
        return h
    }

    @Test func raiseAppliesAtOnceThenFollowsArrivingHeadroom() async throws {
        let h = await limitedHarness()
        h.engine.setLevel(LevelPreset.max.position, for: h.builtIn, source: .shortcut)
        await h.advance(.milliseconds(320))
        #expect(abs((h.controller()?.appliedGain ?? 0) - 0.97 * 1.8) < 1e-6)   // at once, up to what H allows
        #expect(h.controller()?.burstSlot.isRunning == true)
        h.scripted.setGrant(1600.0 / 600, for: h.builtIn, over: .seconds(1))
        await h.advance(.milliseconds(1_700))                             // well before the next 2 s drift tick
        #expect(abs((h.controller()?.appliedGain ?? 0) - peakTop) < 1e-3)
        #expect(h.interlockViolations().isEmpty)
    }

    @Test func burstEndsAfterThreeSeconds() async throws {
        let h = await limitedHarness()
        h.engine.setLevel(LevelPreset.max.position, for: h.builtIn, source: .panel)
        await h.advance(.milliseconds(400))
        #expect(h.controller()?.burstSlot.isRunning == true)
        await h.advance(.milliseconds(3_000))
        #expect(h.controller()?.burstSlot.isRunning == false)
        #expect(abs((h.controller()?.appliedGain ?? 0) - 0.97 * 1.8) < 1e-6)
    }

    @Test func raiseWithinHeadroomNeedsNoBurst() async throws {
        let h = await limitedHarness()
        h.engine.setLevel(LevelPreset.sunlight.position, for: h.builtIn, source: .panel)  // 2.04 > 1.746: limited
        await h.settle()
        #expect(h.controller()?.burstSlot.isRunning == true)
        let low = EngineHarness(reducer: ReferenceReducer(top: peakTop))
        low.setPreferences { $0.capMode = .peak; $0.level = LevelPreset.indoor.position }
        await low.start()
        #expect(await low.boost())
        await low.advance(.seconds(1))
        low.engine.setLevel(LevelPreset.brightRoom.position, for: low.builtIn, source: .panel)
        await low.settle()
        #expect(low.controller()?.burstSlot.isRunning == false)
        await low.advance(.milliseconds(320))
        #expect(abs((low.controller()?.appliedGain ?? 0) - pow(peakTop, 0.5)) < 1e-9)
    }

    /// Headroom recovers by itself: the raise waits for 1.5 s of stability, then ramps to the new limit.
    @Test func recoveryRaiseWaitsForStability() async throws {
        let h = await limitedHarness()
        h.engine.setLevel(LevelPreset.max.position, for: h.builtIn, source: .panel)
        await h.advance(.seconds(4))                                      // the user's burst has ended
        let before = try #require(h.controller()?.appliedGain)
        h.scripted.setGrant(2.2, for: h.builtIn)
        h.signals.emit(.screenParametersChanged)
        await h.advance(.milliseconds(1_200))
        #expect(h.controller()?.appliedGain == before)
        await h.advance(.milliseconds(1_000))
        #expect(abs((h.controller()?.appliedGain ?? 0) - 0.97 * 2.2) < 1e-6)
    }

    /// The same target, but the write parameters change by themselves (Reduce Motion, HDR suppression ending, the
    /// SDR-white estimate): that is not a user raise, so it waits for the recovery rule like any headroom recovery.
    @Test func automaticParameterChangesRaiseThroughRecovery() async throws {
        let h = await limitedHarness()
        h.engine.setLevel(LevelPreset.max.position, for: h.builtIn, source: .panel)
        await h.advance(.seconds(4))                                      // the user's burst has ended
        let before = try #require(h.controller()?.appliedGain)
        h.scripted.setGrant(2.2, for: h.builtIn)                          // no event: only the parameters change
        h.signals.snapshot.reduceMotion = true
        h.engine.reduceNow()
        await h.advance(.milliseconds(1_200))
        #expect(h.controller()?.appliedGain == before)
        await h.advance(.milliseconds(1_000))
        #expect(abs((h.controller()?.appliedGain ?? 0) - 0.97 * 2.2) < 1e-6)
    }

    /// A parameter change the user asked for (a request) still raises at once.
    @Test func requestedParameterChangesRaiseAtOnce() async throws {
        let h = await limitedHarness()
        h.engine.setLevel(LevelPreset.max.position, for: h.builtIn, source: .panel)
        await h.advance(.seconds(4))
        h.scripted.setGrant(2.2, for: h.builtIn)
        h.signals.snapshot.reduceMotion = true
        h.engine.reduceNow(BoostEngine.ControlRequest(source: .shortcut, kind: .level, display: h.builtIn,
                                                      wantsBoost: true))
        await h.advance(.milliseconds(400))
        #expect(abs((h.controller()?.appliedGain ?? 0) - 0.97 * 2.2) < 1e-6)
    }
}
