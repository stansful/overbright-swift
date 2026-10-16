// OverbrightBoostTests/BoostSeamTests.swift — the WP0a seams of OverbrightBoost (ARCHITECTURE.md §10.0): the fixed
// initializers compile against the Core fakes, the seeded writer refuses every write (nothing before WP4 can change a
// display), the ledger keeps baselines and the hang epoch, and the seeded engine publishes idle displays.
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct BoostSeamTests {
    private let fixture = DisplayFixture.builtinXDRLidOpen

    @Test func ledgerKeepsBaselinesAndTheEpoch() throws {
        let ledger = SafetyLedger()
        let display = try #require(fixture.displays.first?.facts.ref)
        #expect(ledger.entries().isEmpty && ledger.hangEpoch == 0)
        ledger.markScaled(display, baseline: .identity(count: 4))
        #expect(ledger.entries().map(\.display) == [display])
        ledger.withLock { $0.hangEpoch += 1 }
        #expect(ledger.hangEpoch == 1)
        ledger.unmark(display.key)
        #expect(ledger.entries().isEmpty)
    }

    /// WP0a's writer refuses every scaled and calibration write and writes no baseline: the fake port sees nothing.
    @Test func theSeededWriterNeverWrites() throws {
        let gamma = FakeGammaPort(fixture: fixture)
        let time = ManualTimeSource()
        let ledger = SafetyLedger()
        let writer = TableWriter(gamma: gamma, ledger: ledger, time: time, journal: RingBufferJournal())
        let facts = try #require(fixture.displays.first?.facts)
        let reading = HeadroomReading(display: facts.ref.id, current: 2.6, potential: 16, reference: 0, time: time.now)
        let request = TableWriter.Request(gain: 1.3, domain: .encoded, baseline: .identity(count: 1024), facts: facts,
                                          capMode: .safe, isOLED: false, sdrWhite: nil, taper: true,
                                          fullBrightnessHeadroom: nil)
        #expect(throws: GammaError.writeRefused) {
            _ = try writer.write(request, to: facts.ref, reading: reading, epoch: ledger.hangEpoch)
        }
        #expect(throws: GammaError.writeRefused) {
            try writer.writeCalibrationFactor(1.1, to: facts.ref, reading: reading, maxFactor: 1.2)
        }
        ledger.markScaled(facts.ref, baseline: .identity(count: 1024))
        #expect(ledger.withLock { writer.writeBaselines(fromLedger: $0) } == 0)
        #expect(gamma.writeCount == 0 && gamma.writes.isEmpty)
    }

    /// The engine's seam initializers; started, it publishes every display idle at Standard and touches no table or
    /// trigger.
    @Test func theSeededEnginePublishesIdleDisplays() async {
        let services = OverbrightServices.preview(fixture: .sidecar)
        let gamma = FakeGammaPort(fixture: .sidecar)
        let headroom = ScriptedHeadroom(fixture: .sidecar, time: services.time)
        let triggers = FakeTriggerFactory(headroom: headroom)
        let engine = BoostEngine(services: services, gamma: gamma, headroom: headroom, triggers: triggers,
                                 conflicts: FakeConflictProbe(), reduce: ReferenceReducer.reduce)
        #expect(engine.status == .initial && engine.serviceName == "boost")
        await engine.start()
        #expect(engine.status.isReady && !engine.status.isOn)
        #expect(engine.status.displays.map(\.key) == services.displays.displays.map(\.ref.key))
        #expect(engine.status.displays.allSatisfy { $0.phase == .idle && $0.appliedGain == 1 })
        engine.setOn(true, source: .panel)
        await engine.stop()
        engine.stopNow()
        #expect(gamma.writeCount == 0 && triggers.openWindowCount == 0 && triggers.made.isEmpty)
    }

    /// WP5's seams: every initializer of §10.0 builds over fakes and does nothing yet.
    @Test func theSafetySeamsDoNothing() async throws {
        let gamma = FakeGammaPort(fixture: fixture)
        let journal = RingBufferJournal()
        let ledger = SafetyLedger()
        let time = ManualTimeSource()
        let writer = TableWriter(gamma: gamma, ledger: ledger, time: time, journal: journal)
        let rescue = LaunchRescue(gamma: gamma, conflicts: FakeConflictProbe(), signals: FakeSystemSignals(),
                                  journal: journal)
        #expect(await rescue.runLaunchCheck() == .alreadyNeutral)
        #expect(await rescue.rescueNow() == .alreadyNeutral)
        let watchdog = HangWatchdog(writer: writer, ledger: ledger, journal: journal)
        watchdog.setActive(true)
        #expect(!watchdog.consumeFiredFlag())
        SignalHandlers(writer: writer, stop: {}).install()
        let report = await SelfTestRunner(drivers: [], time: time, journal: journal, machine: fixture.machine)
            .run(SelfTestOptions())
        #expect(report.displays.isEmpty && report.machine == fixture.machine)
        #expect(gamma.writeCount == 0 && gamma.restoreCount == 0)
    }

    /// The constants of §4.4 keep their documented relations.
    @Test func engineTimingIsConsistent() {
        #expect(EngineTiming.wakeBackoff == EngineTiming.wakeBackoff.sorted())
        #expect(EngineTiming.rampDurationBackToStandard < EngineTiming.rampDurationReduceMotion)
        #expect(EngineTiming.rampDurationReduceMotion < EngineTiming.rampDuration)
        #expect(EngineTiming.hangPing < EngineTiming.hangTimeout)
        #expect(EngineTiming.readyMinimum < EngineTiming.preHeldStable && EngineTiming.preHeldStable < EngineTiming.preHeldMinimum)
        #expect(EngineTiming.minimumRampSteps >= 6)
    }
}
