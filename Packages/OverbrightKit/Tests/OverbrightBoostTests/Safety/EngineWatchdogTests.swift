// OverbrightBoostTests/Safety/EngineWatchdogTests.swift — the engine arms its hang watchdog and the boost marker from
// the safety ledger, so a stall in the middle of a ramp from neutral (the first boost, a reapply after a reset) is
// restored (ARCHITECTURE.md §4.6, §7.4; D7: "a hung but living process"). The watchdog is real (short intervals) and
// pings a queue the test stalls; the engine runs on the manual clock, so the ramp stands still while the queue is
// stalled. The 1 s timeout is far above how late an idle serial queue answers on a loaded machine, so only the test's
// stall makes it fire, and the test waits for that restore with a scheduling margin only a real failure reaches (§9.1).
// `make tsan FILTER=EngineWatchdogTests` runs it under Thread Sanitizer.
import Dispatch
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightBoost

@MainActor @Suite(.serialized) struct EngineWatchdogTests {
    /// An engine whose watchdog pings `queue` every 50 ms and restores after 1 s without an answer.
    private func harness(pinging queue: DispatchQueue) -> EngineHarness {
        let h = EngineHarness()
        h.engine.watchdog = HangWatchdog(writer: h.engine.writer, ledger: h.engine.ledger, journal: h.journal,
                                         pingInterval: .milliseconds(50), timeout: .seconds(1), pinged: queue)
        h.engine.watchdogEnabled = true
        return h
    }

    /// The table is part-way up a ramp: scaled, while the phase still says ramping.
    private func midRamp(_ h: EngineHarness) -> Bool {
        h.phase() == .ramping && (h.liveFactor() ?? 1) > 1.001 && (h.liveFactor() ?? 1) < 1.1
    }

    /// Stalls `queue` until the watchdog restored, then answers again; true when it fired once.
    private func stallUntilRestored(_ queue: DispatchQueue, _ watchdog: HangWatchdog) async -> Bool {
        let stall = Stall()
        queue.async { stall.begin() }
        let fired = await waitUntil(.seconds(120)) { watchdog.fireCount == 1 }
        stall.release()
        return fired
    }

    /// The first boost: the ramp from neutral scales the table step by step without a phase change. The watchdog and
    /// the marker are on from the first scaled step, and a stall then restores the baseline; the steps queued behind
    /// it are refused by the stale epoch until the re-gate.
    @Test func aStallDuringTheFirstRampIsRestored() async throws {
        let queue = DispatchQueue(label: "app.overbright.tests.engine-watchdog.first")
        let h = harness(pinging: queue)
        await h.start()
        #expect(!h.engine.watchdog.isActive)                              // nothing scaled: no timer
        h.engine.setOn(true, source: .panel)
        #expect(await h.advance(until: { midRamp(h) }, step: .milliseconds(5)))
        #expect(h.engine.watchdog.isActive)
        #expect(h.settings[EngineRecords.boostMarker]?.displays == [h.builtIn])
        #expect(await stallUntilRestored(queue, h.engine.watchdog))
        #expect(h.everyTableAtBase && h.engine.ledger.hangEpoch == 1 && h.engine.ledger.entries().isEmpty)
        #expect(!h.engine.watchdog.isActive)                              // the restore emptied the ledger
        await h.advance(.milliseconds(100))
        #expect(h.everyTableAtBase)                                       // the queued steps were refused
        #expect(h.codes.contains("interlock.refusedStaleEpoch") && h.codes.contains("hang.restored"))
        #expect(await h.boost())                                          // re-gated under the new epoch
        #expect(h.engine.watchdog.isActive && h.engine.ledger.isMarked(h.builtIn))
        h.engine.stopNow()
        #expect(!h.engine.watchdog.isActive && h.everyTableAtBase)
    }

    /// A system reset puts our baseline back while the ledger still holds the display; the reapply ramps up from
    /// neutral again. The watchdog never switches off in between, and a stall during that ramp is restored.
    @Test func aStallDuringTheReapplyAfterAResetIsRestored() async throws {
        let queue = DispatchQueue(label: "app.overbright.tests.engine-watchdog.reapply")
        let h = harness(pinging: queue)
        await h.start()
        #expect(await h.boost())
        #expect(h.engine.watchdog.isActive)
        h.gamma.resetToBase(h.id(h.builtIn))
        #expect(await h.advance(until: { h.codes.contains("drift.reapplied") && midRamp(h) }, step: .milliseconds(5)))
        #expect(h.engine.watchdog.isActive && h.settings[EngineRecords.boostMarker] != nil)
        #expect(await stallUntilRestored(queue, h.engine.watchdog))
        #expect(h.everyTableAtBase && h.engine.ledger.hangEpoch == 1)
        await h.advance(.milliseconds(100))
        #expect(h.everyTableAtBase)
        h.engine.stopNow()
        #expect(!h.engine.watchdog.isActive)
    }

    /// A dim from idle is a scaled table too: the watchdog runs from its first step and stops at Standard.
    @Test func aDimRunsTheWatchdogUntilStandard() async throws {
        let queue = DispatchQueue(label: "app.overbright.tests.engine-watchdog.dim")
        let h = harness(pinging: queue)
        await h.start()
        h.engine.setLevel(LevelPosition(-0.5), for: h.builtIn, source: .panel)
        #expect(await h.advance(until: { (h.liveFactor() ?? 1) < 0.999 }, step: .milliseconds(5)))
        #expect(h.engine.watchdog.isActive)
        h.engine.setOn(false, source: .panel)                             // after the rate limiter's 500 ms
        await h.advance(.milliseconds(1_500))
        #expect(h.everyTableAtBase && !h.engine.watchdog.isActive)
        #expect(h.settings[EngineRecords.boostMarker] == nil)
    }
}
