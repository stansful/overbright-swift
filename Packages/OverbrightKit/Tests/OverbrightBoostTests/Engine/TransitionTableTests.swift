// OverbrightBoostTests/Engine/TransitionTableTests.swift — one scenario per row of ARCHITECTURE.md §4.3, against the
// Core fakes, a ManualTimeSource and TestSupport's reference reducer. Every scenario also checks invariant 2 (no
// trigger is removed while its table is scaled) through the harness's order-checking trigger factory.
// Rows covered in more depth elsewhere: the pre-held arm and "boosted (armed pre-held)" (PreHeldTests), user and
// recovery raises (UserRaiseTests), the drift check (DriftCheckTests), re-basing (RebaseTests), the hang watchdog
// (InvariantTests.hangEpochBlocksQueuedWrites), Continue Anyway (EngineRequestTests).
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct TransitionTableTests {
    private let brightRoomGain = pow(ReferenceReducer.defaultTop, 0.5)

    /// A started harness, boosted on the built-in at Bright room.
    private func boostedHarness(_ h: EngineHarness = EngineHarness()) async -> EngineHarness {
        await h.start()
        let boosted = await h.boost()
        #expect(boosted)
        return h
    }

    // MARK: idle

    /// idle → boost: baseline captured, three idle reads, T1 black armed (macOS 27), movement → gating, stable →
    /// ramping → boosted at the requested gain; the table is the baseline × F(G).
    @Test func idleToBoostArmsGatesRampsAndHolds() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(h.phase() == .idle)
        h.engine.setOn(true, source: .panel)
        await h.settle()
        #expect(h.phase() == .arming(rung: 1))
        await h.advance(.milliseconds(500))
        #expect(h.phase() == .gating(rung: 1))
        #expect(await h.boost())
        let made = try #require(h.triggers.made.first)
        #expect(made.request.strategy == .taggedLayer && made.request.pixel == .black)
        let status = try #require(h.displayStatus())
        #expect(abs(status.appliedGain - brightRoomGain) < 1e-9)
        let factor = try #require(h.liveFactor())
        #expect(abs(factor - FactorMath.tableFactor(forLightGain: brightRoomGain, domain: .encoded)) < 1e-4)
        #expect(h.codes.contains("gate.ready"))
        #expect(h.engine.strategyCache.record(for: h.builtIn, osBuild: h.fixture.machine.osBuild)?.rung == 1)
        #expect(h.orderViolations.isEmpty)
    }

    /// idle → dim: the baseline is captured and the table ramps to F(L); no trigger, no headroom needed.
    @Test func idleToDimRampsWithoutTrigger() async throws {
        let h = EngineHarness()
        await h.start()
        h.engine.setLevel(LevelPosition(-0.5), for: h.builtIn, source: .panel)
        await h.advance(.milliseconds(400))
        #expect(h.phase() == .dimmed)
        #expect(h.triggers.made.isEmpty)
        let factor = try #require(h.liveFactor())
        #expect(abs(factor - FactorMath.tableFactor(forLightGain: LevelMapping.dimLight(for: LevelPosition(-0.5)),
                                                    domain: .encoded)) < 1e-4)
        #expect(h.writes().count >= EngineTiming.minimumRampSteps)
    }

    // MARK: dimmed

    /// dimmed → boost: arming starts while the dim factor ramps back to 1; then gate, ramp, boosted.
    @Test func dimmedToBoostRampsBackWhileArming() async throws {
        let h = EngineHarness()
        await h.start()
        h.engine.setLevel(LevelPosition(-0.5), for: h.builtIn, source: .panel)
        await h.advance(.milliseconds(400))
        h.engine.setLevel(LevelPreset.brightRoom.position, for: h.builtIn, source: .panel)
        await h.settle()
        guard case .arming = h.phase() else { Issue.record("not arming: \(String(describing: h.phase()))"); return }
        await h.advance(.milliseconds(400))
        #expect(abs((h.liveFactor() ?? 0) - 1) < 1e-6)
        #expect(await h.boost())
        #expect(h.orderViolations.isEmpty)
    }

    /// dimmed → neutral: ramp to 1, baseline, idle.
    @Test func dimmedToNeutralRampsToBaseline() async throws {
        let h = EngineHarness()
        await h.start()
        h.engine.setLevel(LevelPosition(-0.5), for: h.builtIn, source: .panel)
        await h.advance(.milliseconds(400))
        h.engine.setOn(false, source: .panel)
        await h.settle()
        #expect(h.phase() == .disarming)
        await h.advance(.milliseconds(400))
        #expect(h.phase() == .idle && h.everyTableAtBase)
        #expect(h.engine.ledger.entries().isEmpty)
    }

    /// dimmed → dim(L′): a new ramp to F(L′).
    @Test func dimmedToOtherDimRamps() async throws {
        let h = EngineHarness()
        await h.start()
        h.engine.setLevel(LevelPosition(-0.5), for: h.builtIn, source: .panel)
        await h.advance(.milliseconds(400))
        let before = h.writes().count
        h.engine.setLevel(LevelPosition(-0.75), for: h.builtIn, source: .panel)
        await h.advance(.milliseconds(1_000))
        #expect(h.phase() == .dimmed)
        #expect(h.writes().count - before >= EngineTiming.minimumRampSteps)
        let factor = try #require(h.liveFactor())
        #expect(abs(factor - FactorMath.tableFactor(forLightGain: LevelMapping.dimLight(for: LevelPosition(-0.75)),
                                                    domain: .encoded)) < 1e-4)
    }

    // MARK: arming

    /// A factory that throws for T1 and a T2 whose first present fails: the ladder moves on to T3.
    @Test func failedPresentsMoveToTheNextRung() async throws {
        let h = EngineHarness()
        h.triggers.makeErrors[.taggedLayer] = .colorUnavailable
        h.triggers.failingPresents = [.metalOneShot]
        await h.start()
        #expect(await h.boost())
        #expect(h.controller()?.currentRung?.number == 5)
        #expect(h.liveTriggers().map(\.request.strategy) == [.metalKeepAlive])
        #expect(h.codes.filter { $0 == "rung.presentFailed" }.count == 4)
    }

    /// No movement 2.5 s after the first present: rung n+1 is armed before rung n is removed (make before break).
    @Test func rungTimeoutEscalatesMakeBeforeBreak() async throws {
        let h = EngineHarness()
        h.scripted.update(h.builtIn) { $0.respondingStrategies = [.metalOneShot] }
        await h.start()
        h.engine.setOn(true, source: .panel)
        await h.advance(.milliseconds(2_600))
        #expect(h.phase() == .arming(rung: 1))
        await h.advance(.milliseconds(200))
        #expect(h.phase() == .arming(rung: 2))
        let events = h.checkedTriggers.events
        let makeSecond = try #require(events.firstIndex(of: "make:taggedLayer/bright"))
        let removeFirst = try #require(events.firstIndex(of: "remove:taggedLayer/black"))
        #expect(makeSecond < removeFirst)
        #expect(await h.boost())
        #expect(h.controller()?.currentRung?.number == 3)
    }

    /// The last rung times out: trigger removed, baseline, failed(headroomNeverArrived), one failed try.
    @Test func lastRungTimeoutFails() async throws {
        let h = EngineHarness()
        h.scripted.update(h.builtIn) { $0.respondingStrategies = [] }
        await h.start()
        h.engine.setOn(true, source: .panel)
        let failed = await h.advance(until: { h.phase() == .failed(.headroomNeverArrived) }, limit: .seconds(25))
        #expect(failed)
        #expect(h.triggers.made.count == 7)
        #expect(h.liveTriggers().isEmpty && h.everyTableAtBase)
        #expect(h.displayStatus()?.failedTries == 1)
        #expect(h.controller()?.trip == .headroomNeverArrived)
    }

    /// macOS suppresses HDR: the current rung is kept and the ladder does not escalate; it resumes afterwards.
    @Test func hdrSuppressionKeepsTheRung() async throws {
        let h = EngineHarness()
        h.scripted.update(h.builtIn) { $0.respondingStrategies = [.metalOneShot] }
        h.signals.snapshot.isHDRSuppressed = true
        await h.start()
        h.engine.setOn(true, source: .panel)
        await h.advance(.seconds(10))
        #expect(h.phase() == .arming(rung: 1))
        #expect(h.triggers.made.count == 1)
        h.signals.snapshot.isHDRSuppressed = false
        h.signals.emit(.hdrSuppressionEnded)
        #expect(await h.boost())
        #expect(h.controller()?.currentRung?.number == 3)
    }

    /// Potential falls to 1 while arming: stop escalating, remove the trigger, baseline, failed.
    @Test func potentialAtOneStopsArming() async throws {
        let h = EngineHarness()
        h.scripted.update(h.builtIn) { $0.respondingStrategies = [] }
        await h.start()
        h.engine.setOn(true, source: .panel)
        await h.advance(.milliseconds(600))
        h.scripted.update(h.builtIn) { $0.potential = 1 }
        await h.advance(.milliseconds(200))
        #expect(h.phase() == .failed(.headroomNeverArrived))
        #expect(h.liveTriggers().isEmpty && h.everyTableAtBase)
        #expect(h.triggers.made.count == 1)
    }

    // MARK: gating

    /// Moved but never stable within 12 s: the rung fails and the next one is armed.
    @Test func gateTimeoutEscalates() async throws {
        let h = EngineHarness()
        h.scripted.update(h.builtIn) { $0.rampDuration = .seconds(20) }   // 0.125 per 1.5 s: never stable
        await h.start()
        h.engine.setOn(true, source: .panel)
        await h.advance(.seconds(2))
        #expect(h.phase() == .gating(rung: 1))                          // moved after ≈ 1 s
        await h.advance(.seconds(12))
        #expect(h.triggers.made.count == 2)
        #expect(h.phase() == .arming(rung: 2) || h.phase() == .gating(rung: 2))
        #expect(h.codes.contains("rung.timedOut"))
    }

    /// Ready learns the lowest ready headroom (the taper's reference).
    @Test func readyLearnsTheLowestReadyHeadroom() async throws {
        let h = await boostedHarness()
        let record = try #require(h.engine.strategyCache.record(for: h.builtIn, osBuild: h.fixture.machine.osBuild))
        #expect(abs((record.lowestReadyHeadroom ?? 0) - 1600.0 / 600) < 1e-6)
    }

    // MARK: boosted

    /// A lower target ramps down over 300 ms and stays boosted.
    @Test func lowerTargetRampsDown() async throws {
        let h = await boostedHarness()
        await h.advance(.seconds(1))                                    // past the rate limiter's 500 ms
        let before = h.writes().count
        h.engine.setLevel(LevelPreset.indoor.position, for: h.builtIn, source: .panel)
        await h.settle()
        #expect(h.phase() == .ramping)
        await h.advance(.milliseconds(320))
        #expect(h.phase() == .boosted)
        #expect(h.writes().count - before == RampPlanner.stepCount(for: EngineTiming.rampDuration))
        #expect(abs((h.displayStatus()?.appliedGain ?? 0) - pow(ReferenceReducer.defaultTop, 0.25)) < 1e-9)
    }

    /// A user raise applies at once (one ramp) when headroom supports it.
    @Test func userRaiseAppliesAtOnce() async throws {
        let h = await boostedHarness()
        h.engine.setLevel(LevelPreset.max.position, for: h.builtIn, source: .panel)
        await h.advance(.milliseconds(320))
        #expect(h.phase() == .boosted)
        #expect(abs((h.displayStatus()?.appliedGain ?? 0) - ReferenceReducer.defaultTop) < 1e-9)
    }

    /// A raise driven by headroom recovery waits for 1.5 s of stable headroom and needs ≥ 5 %.
    @Test func headroomRecoveryRaisesAfterStability() async throws {
        let h = EngineHarness(reducer: ReferenceReducer(top: 2.587))
        h.setPreferences { $0.capMode = .peak; $0.level = LevelPreset.max.position }
        h.settings[DisplaySettings.boostOnlyNearFullBrightness] = false   // the taper would read H's rise as dimming
        h.scripted.update(h.builtIn) { $0.grant = 2.0 }
        await h.start()
        #expect(await h.boost())
        #expect(abs((h.displayStatus()?.appliedGain ?? 0) - 0.97 * 2.0) < 1e-6)
        h.scripted.setGrant(2.05, for: h.builtIn)                        // +2.5 %: below the hysteresis
        await h.advance(.seconds(5))
        #expect(abs((h.displayStatus()?.appliedGain ?? 0) - 0.97 * 2.0) < 1e-6)
        h.scripted.setGrant(1600.0 / 600, for: h.builtIn)
        h.signals.emit(.screenParametersChanged)
        await h.advance(.seconds(1))
        #expect(abs((h.displayStatus()?.appliedGain ?? 0) - 0.97 * 2.0) < 1e-6)   // not yet: stability first
        await h.advance(.seconds(2))
        #expect(abs((h.displayStatus()?.appliedGain ?? 0) - 2.587) < 1e-3)
    }

    /// Applied above 0.98 × H: one write down to 0.97 × H at once; below H 1.03 the baseline.
    @Test func headroomDropLowersInOneStep() async throws {
        let h = EngineHarness()
        h.setPreferences { $0.capMode = .peak }
        await h.start()
        #expect(await h.boost())
        let before = h.writes().count
        h.scripted.setGrant(1.2, for: h.builtIn)
        h.signals.emit(.screenParametersChanged)
        #expect(h.writes().count == before + 1)
        #expect(abs((h.displayStatus()?.appliedGain ?? 0) - 0.97 * 1.2) < 1e-9)
        h.scripted.setGrant(1.01, for: h.builtIn)
        h.signals.emit(.screenParametersChanged)
        #expect(h.writes().count == before + 2)
        #expect(h.everyTableAtBase)
        #expect(h.phase() == .boosted)
    }

    /// The drift check sees a reset (another writer died): reapply with a ramp and count a repair.
    @Test func driftResetReapplies() async throws {
        let h = await boostedHarness()
        h.gamma.simulateOtherWriterDeath()
        await h.advance(.milliseconds(2_100))
        #expect(h.codes.contains("watchdog.reset"))
        await h.advance(.milliseconds(600))
        #expect(h.phase() == .boosted)
        #expect(abs((h.liveFactor() ?? 0) - FactorMath.tableFactor(forLightGain: brightRoomGain, domain: .encoded)) < 1e-4)
        #expect(h.controller()?.repairs.count == 1)
    }

    /// The trigger is occluded: baseline at once, trigger kept, suspended(occluded); visible again re-gates.
    @Test func occlusionSuspendsAndVisibleRegates() async throws {
        let h = await boostedHarness()
        h.triggers.setOccluded(true, on: h.builtIn)
        #expect(h.everyTableAtBase)
        #expect(h.phase() == .suspended(.occluded))
        #expect(h.liveTriggers().count == 1)
        h.triggers.setOccluded(false, on: h.builtIn)
        #expect((h.liveTriggers().first?.representCount ?? 0) >= 1)
        #expect(await h.boost())
        #expect(h.orderViolations.isEmpty)
    }

    /// AppKit moved the trigger to another screen: baseline, that window removed at once, wait for the pass.
    @Test func windowMovedToAnotherScreenRemovesIt() async throws {
        let h = await boostedHarness()
        h.triggers.moveWindows(on: h.builtIn, toScreen: 99)
        #expect(h.everyTableAtBase)
        #expect(h.liveTriggers().isEmpty)
        #expect(h.phase() == .suspended(.reconfiguring))
        await h.advance(.seconds(3))
        #expect(h.phase() == .suspended(.reconfiguring))
        h.signals.emit(.displaysReconfigured)
        #expect(await h.boost())
        #expect(h.orderViolations.isEmpty)
    }

    // MARK: shields and the console

    /// A shield event: the baseline is written before `emit` returns; the trigger is kept.
    @Test func shieldWritesBaselineSynchronously() async throws {
        let h = await boostedHarness()
        h.signals.snapshot.isScreenLocked = true
        h.signals.emit(.locked)
        #expect(h.everyTableAtBase)
        #expect(h.phase() == .suspended(.shielded))
        #expect(h.liveTriggers().count == 1)
    }

    /// Off the console: baseline, triggers removed at once, no write at all until the session is active again.
    @Test func sessionOffConsoleWritesNothing() async throws {
        let h = await boostedHarness()
        h.signals.snapshot.isSessionActive = false
        h.signals.emit(.sessionResigned)
        #expect(h.everyTableAtBase && h.liveTriggers().isEmpty)
        #expect(h.phase() == .suspended(.notOnConsole))
        let writes = h.gamma.writeCount
        h.engine.setLevel(LevelPreset.max.position, for: h.builtIn, source: .panel)
        h.engine.setLevel(LevelPosition(-0.6), for: h.builtIn, source: .panel)
        await h.advance(.seconds(5))
        #expect(h.gamma.writeCount == writes)
        h.signals.snapshot.isSessionActive = true
        h.signals.emit(.sessionBecameActive)
        await h.advance(.seconds(1))
        #expect(h.phase() == .dimmed)
    }

    /// Unlock: the kept trigger is re-presented and the display re-gates from the cached rung.
    @Test func unlockRepresentsAndRegates() async throws {
        let h = await boostedHarness()
        h.signals.snapshot.isScreenLocked = true
        h.scripted.setOverride(1)
        h.signals.emit(.locked)
        await h.advance(.seconds(3))
        h.signals.snapshot.isScreenLocked = false
        h.scripted.setOverride(nil)
        h.signals.emit(.unlocked)
        #expect(await h.boost())
        #expect(h.triggers.made.count == 1)
        #expect((h.liveTriggers().first?.representCount ?? 0) >= 1)
    }

    /// Suspended for 10 s: the trigger is removed, the display stays suspended.
    @Test func suspendedTriggerLingersTenSeconds() async throws {
        let h = await boostedHarness()
        h.signals.snapshot.isScreenLocked = true
        h.signals.emit(.locked)
        await h.advance(.seconds(9))
        #expect(h.liveTriggers().count == 1)
        await h.advance(.milliseconds(1_100))
        #expect(h.liveTriggers().isEmpty)
        #expect(h.phase() == .suspended(.shielded))
    }

    // MARK: neutral, Back to Standard, disarming

    /// Master off: disarming ramps to 1, writes the baseline, then removes the trigger; idle with no tasks.
    @Test func neutralDisarmsRampBaselineThenTrigger() async throws {
        let h = await boostedHarness()
        await h.advance(.seconds(1))                                    // past the rate limiter's 500 ms
        let before = h.writes().count
        h.engine.setOn(false, source: .panel)
        await h.settle()
        #expect(h.phase() == .disarming)
        #expect(h.liveTriggers().count == 1)
        await h.advance(.milliseconds(320))
        #expect(h.phase() == .idle && h.everyTableAtBase && h.liveTriggers().isEmpty)
        #expect(h.writes().count - before == RampPlanner.stepCount(for: EngineTiming.rampDuration))
        #expect(h.orderViolations.isEmpty)
        #expect(h.engine.activeTaskCount == 0)
    }

    /// Back to Standard: master off within a 120 ms ramp, stored levels kept.
    @Test func backToStandardIsFastAndKeepsLevels() async throws {
        let h = await boostedHarness()
        h.engine.setLevel(LevelPreset.sunlight.position, for: h.builtIn, source: .panel)
        await h.advance(.milliseconds(400))
        h.engine.returnToStandard(source: .shortcut)
        #expect(!h.engine.status.isOn)
        await h.advance(.milliseconds(120), step: .milliseconds(5))
        #expect(h.phase() == .idle && h.everyTableAtBase && h.liveTriggers().isEmpty)
        #expect(h.settings[DisplaySettings.perDisplay][h.builtIn]?.level == LevelPreset.sunlight.position)
        #expect(h.orderViolations.isEmpty)
    }

    /// A new boost target while disarming: the disarm stops where it is and the same trigger boosts again.
    @Test func boostDuringDisarmResumes() async throws {
        let h = await boostedHarness()
        await h.advance(.seconds(1))
        h.engine.setOn(false, source: .panel)
        await h.advance(.milliseconds(100))
        #expect(h.phase() == .disarming)
        h.engine.setOn(true, source: .panel)
        await h.advance(.milliseconds(900))
        #expect(h.phase() == .boosted)
        #expect(h.triggers.made.count == 1 && h.liveTriggers().count == 1)
        #expect(abs((h.displayStatus()?.appliedGain ?? 0) - brightRoomGain) < 1e-9)
    }

    /// Compatibility mode dims with the overlay alone (a factor below 1, no EDR request) and removes it at Standard.
    @Test func overlayDimsWithoutATable() async throws {
        let h = EngineHarness()
        h.setPreferences { $0.mechanism = .overlay }
        await h.start()
        h.engine.setLevel(LevelPosition(-0.5), for: h.builtIn, source: .panel)
        await h.advance(.milliseconds(400))
        #expect(h.phase() == .dimmed)
        let overlay = try #require(h.triggers.liveOverlays(on: h.builtIn).first)
        #expect(overlay.factor < 1 && overlay.factors.last?.headroomRequest == 1)
        #expect(h.gamma.writeCount == 0 && h.triggers.made.isEmpty)
        h.engine.setOn(false, source: .panel)
        await h.advance(.milliseconds(400))
        #expect(h.phase() == .idle && h.triggers.liveOverlays(on: h.builtIn).isEmpty)
        #expect(h.orderViolations.isEmpty)
    }

    // MARK: displays and reconfiguration

    /// A display is removed while boosted: its windows go at once, its controller and ledger entry are dropped; the
    /// other display keeps boosting.
    @Test func displayRemovedWhileBoosted() async throws {
        let h = EngineHarness(fixture: .russianNames)
        await h.start()
        #expect(await h.boost(DisplayFixture.Keys.mpg322ux))
        #expect(await h.boost(h.builtIn))
        let msi = DisplayFixture.Keys.mpg322ux
        h.gamma.removeDisplay(2)
        h.directory.remove(msi)
        h.signals.emit(.displayRemoved(2))
        #expect(h.liveTriggers(msi).isEmpty)
        #expect(h.engine.controllers[msi] == nil)
        #expect(!h.engine.ledger.entries().contains { $0.display.key == msi })
        await h.advance(.seconds(3))
        #expect(h.phase(h.builtIn) == .boosted)
        #expect(h.engine.status.displays.map(\.key) == [h.builtIn])
    }

    /// Compatibility mode: the overlay goes to factor 1 at the begin phase of a reconfiguration, then reapplies.
    @Test func overlayGoesToOneWhenConfigurationBegins() async throws {
        let h = EngineHarness()
        h.setPreferences { $0.mechanism = .overlay }
        await h.start()
        #expect(await h.boost())
        let overlay = try #require(h.triggers.liveOverlays(on: h.builtIn).first)
        #expect(overlay.factor > 1)
        #expect(h.triggers.made.isEmpty && h.gamma.writeCount == 0)
        h.signals.emit(.displayConfigurationBegan)
        #expect(overlay.factor == 1)
        h.signals.emit(.displaysReconfigured)
        await h.advance(.milliseconds(400))
        #expect(overlay.factor > 1)
    }

    /// Wake: settle 1 s, then the cached rung only, with backoff, never escalating; failed after the last backoff.
    @Test func wakeRetriesTheCachedRungOnlyWithBackoff() async throws {
        let h = await boostedHarness()
        h.signals.snapshot.isSystemSleeping = true
        h.signals.emit(.willSleep)
        #expect(h.everyTableAtBase)
        h.scripted.setOverride(1)                                       // headroom refuses after wake
        h.signals.snapshot.isSystemSleeping = false
        h.signals.emit(.didWake)
        await h.advance(.milliseconds(900))
        #expect(h.phase() == .suspended(.displayAsleep))
        let failed = await h.advance(until: { h.phase() == .failed(.headroomNeverArrived) }, limit: .seconds(70),
                                     step: .milliseconds(50))
        #expect(failed)
        #expect(h.triggers.made.allSatisfy { $0.request.strategy == .taggedLayer && $0.request.pixel == .black })
        let record = h.engine.strategyCache.record(for: h.builtIn, osBuild: h.fixture.machine.osBuild)
        #expect(record?.rung == 1 && record?.failures == 0)               // quarantined: no count against the rung
    }

    /// failed(headroomNeverArrived) clears by itself on wake, unlock, reconfiguration and Try Again.
    @Test func headroomNeverArrivedRetries() async throws {
        let h = EngineHarness()
        h.scripted.update(h.builtIn) { $0.respondingStrategies = [] }
        await h.start()
        h.engine.setOn(true, source: .panel)
        #expect(await h.advance(until: { h.phase() == .failed(.headroomNeverArrived) }, limit: .seconds(25)))
        h.signals.emit(.unlocked)
        await h.settle()
        guard case .arming = h.phase() else { Issue.record("unlock did not retry"); return }
        #expect(await h.advance(until: { h.phase() == .failed(.headroomNeverArrived) }, limit: .seconds(25)))
        h.engine.retry(h.builtIn)
        await h.settle()
        guard case .arming = h.phase() else { Issue.record("Try Again did not retry"); return }
        #expect(await h.advance(until: { h.phase() == .failed(.headroomNeverArrived) }, limit: .seconds(25)))
        h.scripted.update(h.builtIn) { $0.respondingStrategies = nil }
        h.signals.emit(.displaysReconfigured)
        #expect(await h.boost())
        #expect(h.displayStatus()?.failedTries == 3)
    }

    /// Flicker, repair and attributed-drift trips clear only by Try Again, Continue Anyway or the app quitting.
    @Test func driftTripsClearOnlyByUserOrTermination() async throws {
        let h = await boostedHarness()
        let app = ConflictingApp(entryID: "s3", severity: .conditional, bundleID: "com.example.tool", processID: 42,
                                 displayName: "Tool")
        h.conflicts.driftAttribution = app
        h.gamma.foreignWrite(GammaTable.identity(count: 1024).scaled(by: 0.8), to: 1)
        await h.advance(.milliseconds(2_100))
        #expect(h.phase() == .failed(.attributedDrift(app)))
        h.signals.emit(.unlocked)
        h.signals.emit(.didWake)
        await h.advance(.seconds(2))
        #expect(h.phase() == .failed(.attributedDrift(app)))
        h.signals.emit(.appTerminated(bundleID: app.bundleID, processID: app.processID))
        await h.settle()
        #expect(h.controller()?.trip == nil)
        #expect(await h.boost())
    }

    /// A residue at launch fails the display; it clears when the table matches its base again (a profile event).
    @Test func foreignTableAtLaunchClearsWhenTheTableMatches() async throws {
        let h = EngineHarness()
        h.gamma.addDisplay(1, base: .identity(count: 1024), table: GammaTable.identity(count: 1024).scaled(by: 1.25))
        await h.start()
        h.engine.setOn(true, source: .panel)
        await h.settle()
        #expect(h.phase() == .failed(.foreignTableAtLaunch))
        #expect(h.triggers.made.isEmpty && h.gamma.writeCount == 0)
        h.gamma.resetToBase(1)
        h.signals.emit(.colorProfileChanged)
        await h.settle()
        #expect(h.controller()?.trip == nil)
        #expect(await h.boost())
    }
}
