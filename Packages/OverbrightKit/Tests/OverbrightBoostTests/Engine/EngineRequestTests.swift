// OverbrightBoostTests/Engine/EngineRequestTests.swift — the remaining `BoostControl` requests and lifecycle
// (ARCHITECTURE.md §3.6, §4.9, §7.2, §7.4): Continue Anyway (until the app quits), readiness and the launch behaviour,
// the ramped and the synchronous stop, the self-test and calibration holds, Reset Display Colors, the launch check's
// residue and the boost-only signal sources.
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct EngineRequestTests {
    private let app = ConflictingApp(entryID: "s2-entry", severity: .gammaWriter, bundleID: "com.example.warm",
                                     processID: 4242, displayName: "Warm")

    @Test func continueAnywayLastsUntilTheAppQuits() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        for _ in 0..<5 where h.phase() != .failed(.repairBudgetExceeded) {
            h.gamma.resetToBase(1)
            await h.advance(.milliseconds(2_600))
        }
        #expect(h.phase() == .failed(.repairBudgetExceeded))
        h.signals.emit(.unlocked)
        await h.settle()
        #expect(h.phase() == .failed(.repairBudgetExceeded))             // unlock never restarts a fight
        h.engine.continueAnyway(app)
        #expect(h.inputs.last?.continuedEntryIDs == [app.entryID])
        #expect(await h.boost())
        h.signals.emit(.appTerminated(bundleID: app.bundleID, processID: app.processID))
        await h.advance(.milliseconds(100))
        #expect(h.inputs.last?.continuedEntryIDs.isEmpty == true)
    }

    @Test func startFollowsTheLaunchBehaviourAndOffWins() async throws {
        let on = EngineHarness()
        on.settings[GeneralSettings.launchBehavior] = .launchAndEnable
        await on.start()
        #expect(on.engine.status.isReady && on.engine.status.isOn)
        let off = EngineHarness()
        off.settings[GeneralSettings.launchBehavior] = .launchAndEnable
        off.engine.launchArguments = LaunchArguments(["Overbright", "--off"])
        await off.start()
        #expect(off.engine.status.isReady && !off.engine.status.isOn)
        let keep = EngineHarness()
        await keep.start()
        #expect(!keep.engine.status.isOn)
    }

    @Test func rampedStopEndsNeutralWithNothingRunning() async throws {
        let h = EngineHarness(fixture: .russianNames)
        await h.start()
        #expect(await h.boost(h.builtIn))
        h.engine.setLevel(LevelPosition(-0.5), for: DisplayFixture.Keys.mpg322ux, source: .panel)
        await h.advance(.milliseconds(400))
        async let stopped: Void = h.engine.stop()
        await h.advance(.milliseconds(400))
        await stopped
        #expect(h.everyTableAtBase && h.triggers.openWindowCount == 0)
        #expect(h.engine.activeTaskCount == 0 && h.signals.observerCount == 0)
        #expect(h.engine.settings[EngineRecords.boostMarker] == nil)
    }

    @Test func stopNowWritesBaselinesAtOnce() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        #expect(h.engine.settings[EngineRecords.boostMarker]?.displays == [h.builtIn])
        h.engine.stopNow()
        #expect(h.everyTableAtBase && h.triggers.openWindowCount == 0 && h.engine.ledger.entries().isEmpty)
        #expect(h.engine.settings[EngineRecords.boostMarker] == nil)
    }

    @Test func boostOnlySourcesFollowActivity() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(h.signals.boostActiveCalls.isEmpty)
        h.engine.setOn(true, source: .panel)
        #expect(h.signals.refreshPowerNowCount >= 1)
        #expect(await h.boost())
        #expect(h.signals.boostActiveCalls.last == true)
        h.engine.setOn(false, source: .panel)
        await h.advance(.seconds(1))
        #expect(h.signals.boostActiveCalls.last == false)
    }

    @Test func selfTestHoldsTheMasterOffAndRestoresIt() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        let report = await h.engine.runSelfTest(SelfTestOptions())
        #expect(report.machine == h.fixture.machine)
        #expect(h.engine.status.isOn)                                     // restored afterwards
        #expect(await h.boost())
    }

    @Test func calibrationHoldsTheMasterOffWhileItLives() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        var session = h.engine.beginCalibration(of: h.builtIn)
        #expect(session != nil)
        #expect(!h.engine.status.isOn && h.everyTableAtBase && h.liveTriggers().isEmpty)
        h.engine.setOn(true, source: .panel)
        #expect(!h.engine.status.isOn)                                    // held off
        session = nil
        _ = session
        h.engine.setOn(true, source: .panel)
        #expect(h.engine.status.isOn)
        #expect(h.engine.beginCalibration(of: DisplayKey(rawValue: "0B21E7F1-0000-4000-8000-0000000000FF")) == nil)
    }

    /// The calibration seam writes only through the writer, bounded by its max factor and the live headroom.
    @Test func calibrationFactorsGoThroughTheWriter() async throws {
        let h = EngineHarness()
        await h.start()
        let controller = try #require(h.controller())
        #expect(throws: GammaError.writeRefused) { try controller.writeCalibrationFactor(1.2, maxFactor: 2) }  // H 1
        let rung = LadderPlanner.request(for: LadderPlanner.table[0], facts: controller.facts, potential: 16)
        #expect(await controller.arm(rung: rung))
        await h.advance(.seconds(2))
        try controller.writeCalibrationFactor(1.2, maxFactor: 2)
        #expect(abs((h.liveFactor() ?? 0) - 1.2) < 1e-6)
        #expect(throws: GammaError.writeRefused) { try controller.writeCalibrationFactor(2.6, maxFactor: 3) }
        controller.returnToStandard()
        #expect(h.everyTableAtBase && h.engine.ledger.entries().isEmpty && h.liveTriggers().isEmpty)
    }

    @Test func resetDisplayColorsReturnsToStandardFirst() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        let outcome = await h.engine.rescueDisplayColors()
        #expect(outcome == .alreadyNeutral)                               // WP5's seam until its body lands
        #expect(h.everyTableAtBase)
        #expect(h.engine.status.isOn)
        #expect(await h.boost())
    }

    @Test func launchResidueFailsTheDisplay() async throws {
        let h = EngineHarness()
        await h.start()
        h.engine.applyLaunchCheck(.residueRemains(displays: [h.builtIn]))
        #expect(h.controller()?.trip == .foreignTableAtLaunch)
        h.engine.setOn(true, source: .panel)
        await h.advance(.seconds(1))
        #expect(h.phase() == .failed(.foreignTableAtLaunch) && h.triggers.made.isEmpty)
        h.engine.retry(h.builtIn)
        #expect(await h.boost())
    }

    @Test func mirroredDisplayHasNoReadingAndOnlyDims() async throws {
        let h = EngineHarness(fixture: .hardwareMirror)
        await h.start()
        let projector = DisplayFixture.Keys.projector
        h.engine.setLevel(LevelPosition(-0.5), for: projector, source: .panel)
        await h.advance(.milliseconds(400))
        #expect(h.phase(projector) == .dimmed)
        h.engine.setLevel(LevelPreset.max.position, for: projector, source: .panel)
        await h.advance(.seconds(2))
        #expect(h.phase(projector) == .idle && h.liveTriggers(projector).isEmpty)
    }
}
