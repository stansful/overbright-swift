// OverbrightBoostTests/Engine/RebaseAtRestTests.swift — the event-driven re-base of a display at rest (ARCHITECTURE.md
// §4.8: "scaled, dimmed or idle alike"; §4.3: "whether or not the display is scaled"). WindowServer may keep our last
// baseline write over a profile, preset or HDR change; an idle or failed display we wrote is judged at the event, so
// the old curve neither stays on screen nor becomes the next arm's or calibration's baseline (§4.5 invariant 5).
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct RebaseAtRestTests {
    private let base = GammaTable.identity(count: 1024)
    /// An HDR toggle or preset change gives the display a new base (per-channel white point).
    private let newBase: GammaTable = {
        func channel(_ scale: Double) -> [Float] { (0..<1024).map { Float(scale * Double($0) / 1023) } }
        return GammaTable(red: channel(0.94), green: channel(0.97), blue: channel(0.91))
    }()

    /// Boosted, then off: idle at the old base, which we wrote last.
    private func boostThenOff(_ h: EngineHarness) async {
        await h.start()
        #expect(await h.boost())
        h.engine.setOn(false, source: .panel)
        await h.advance(.seconds(1))
        #expect(h.phase() == .idle && h.table() == base)
    }

    /// Boosted again: the baseline is the new base and "off" restores it.
    private func expectNextArmUsesTheNewBase(_ h: EngineHarness) async {
        #expect(await h.boost())
        #expect(h.controller()?.baseline == newBase)
        let factor = h.controller()?.appliedFactor ?? 1
        #expect(factor > 1 && h.table()?.matches(newBase.scaled(by: factor), tolerance: 1e-6) == true)
        h.engine.setOn(false, source: .panel)
        await h.advance(.seconds(1))
        #expect(h.phase() == .idle && h.table() == newBase && h.engine.ledger.entries().isEmpty)
    }

    /// WindowServer kept our old baseline write: the new profile base is adopted and written at the event, once, and
    /// the next arm multiplies it.
    @Test func idleDisplayKeepingOurTableGetsTheNewBase() async throws {
        let h = EngineHarness()
        await boostThenOff(h)
        let before = h.gamma.writeCount
        h.gamma.changeBase(newBase, for: 1, appliesNow: false)
        h.signals.emit(.colorProfileChanged)
        await h.advance(.seconds(2))
        #expect(h.table() == newBase && h.controller()?.baseline == newBase)
        #expect(h.gamma.writeCount == before + 1 && h.codes.contains("baseline.adopted"))
        #expect(h.engine.activeTaskCount == 0 && h.liveTriggers().isEmpty)
        await expectNextArmUsesTheNewBase(h)
    }

    /// WindowServer applied the new table itself: it is adopted as it is, without a write.
    @Test func idleDisplayAdoptsWindowServersNewTable() async throws {
        let h = EngineHarness()
        await boostThenOff(h)
        let before = h.gamma.writeCount
        h.gamma.changeBase(newBase, for: 1)
        h.signals.emit(.displaysReconfigured)
        await h.advance(.seconds(3))
        #expect(h.gamma.writeCount == before && h.controller()?.baseline == newBase)
        await expectNextArmUsesTheNewBase(h)
    }

    /// A failed display keeps no old curve either; Try Again arms on the new base.
    @Test func failedDisplayKeepingOurTableGetsTheNewBase() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        h.controller()?.fail(.repairBudgetExceeded)
        await h.advance(.milliseconds(200))
        #expect(h.phase() == .failed(.repairBudgetExceeded) && h.table() == base)
        h.gamma.changeBase(newBase, for: 1, appliesNow: false)
        h.signals.emit(.accessibilityDisplayOptionsChanged)
        await h.advance(.seconds(1))
        #expect(h.table() == newBase && h.controller()?.baseline == newBase)
        h.engine.retry(h.builtIn)
        await expectNextArmUsesTheNewBase(h)
    }

    /// Off the console nothing is written (D27): the event stays pending, the old curve is not captured, and the new
    /// base is written once the session is back on the console.
    @Test func offTheConsoleTheNewBaseWaitsForTheSession() async throws {
        let h = EngineHarness()
        await boostThenOff(h)
        h.signals.snapshot.isSessionActive = false
        h.signals.emit(.sessionResigned)
        await h.advance(.milliseconds(200))
        let before = h.gamma.writeCount
        h.gamma.changeBase(newBase, for: 1, appliesNow: false)
        h.signals.emit(.colorProfileChanged)
        await h.advance(.seconds(2))
        #expect(h.gamma.writeCount == before && h.table() == base && h.controller()?.pendingRebase != nil)
        h.signals.snapshot.isSessionActive = true
        h.signals.emit(.sessionBecameActive)
        await h.advance(.seconds(1))
        #expect(h.table() == newBase && h.controller()?.pendingRebase == nil)
        await expectNextArmUsesTheNewBase(h)
    }

    /// The write of the new base fails at the event and again at the next reduction: the arm keeps the adopted base
    /// instead of capturing our old write still on screen, so its ramp multiplies the new base.
    @Test func anUnwrittenNewBaseIsNeverCapturedFromOurOldWrite() async throws {
        let h = EngineHarness()
        await boostThenOff(h)
        h.gamma.failNextWrite(with: .coreGraphics(code: 1000))
        h.gamma.changeBase(newBase, for: 1, appliesNow: false)
        h.signals.emit(.colorProfileChanged)
        #expect(h.table() == base && h.controller()?.baseline == newBase && h.controller()?.pendingRebase != nil)
        h.gamma.failNextWrite(with: .coreGraphics(code: 1000))       // the retry before the arm fails too
        await expectNextArmUsesTheNewBase(h)
        #expect(h.codes.contains("baseline.keptOverOwnWrite"))
    }

    /// A base event judged while suspended off the console cannot write the new base (D27): it stays pending, so once
    /// back on the console the display at rest gets the new base instead of keeping the old curve (C-BOOST-16).
    @Test func aBaseEventJudgedOffTheConsoleIsWrittenOnceBack() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        h.signals.snapshot.isSessionActive = false
        h.signals.emit(.sessionResigned)
        await h.advance(.milliseconds(200))
        #expect(h.phase() == .suspended(.notOnConsole) && h.table() == base)
        let before = h.gamma.writeCount
        h.gamma.changeBase(newBase, for: 1, appliesNow: false)
        h.signals.emit(.colorProfileChanged)
        await h.advance(.seconds(2))
        #expect(h.gamma.writeCount == before && h.controller()?.baseline == newBase)
        #expect(h.controller()?.pendingRebase != nil)                    // judged, but not written
        h.engine.setOn(false, source: .panel)
        await h.advance(.seconds(1))
        h.signals.snapshot.isSessionActive = true
        h.signals.emit(.sessionBecameActive)
        await h.advance(.seconds(1))
        #expect(h.phase() == .idle && h.table() == newBase && h.controller()?.pendingRebase == nil)
        await expectNextArmUsesTheNewBase(h)
    }

    /// A foreign baseline (a continued S2 app's curve) survives a reconfiguration that changed no profile: the re-base
    /// at rest finds our table still on screen, and the profile base differs from the baseline only because the
    /// baseline is foreign (C-BOOST-17). The boosted re-base keeps it too.
    @Test(arguments: [false, true])
    func aForeignBaselineSurvivesAReconfiguration(boosted: Bool) async throws {
        let h = EngineHarness()
        let curve = newBase
        h.gamma.foreignWrite(curve, to: 1)                                  // a warm-light tool's curve, kept going
        await h.start()
        #expect(await h.boost())
        #expect(h.controller()?.baseline == curve && h.codes.contains("baseline.foreign"))
        if !boosted {
            h.engine.setOn(false, source: .panel)
            await h.advance(.seconds(1))
            #expect(h.phase() == .idle && h.table() == curve)
        }
        let adoptions = h.codes.filter { $0 == "baseline.adopted" }.count
        h.signals.emit(.displaysReconfigured)
        await h.advance(.seconds(3))
        #expect(h.controller()?.baseline == curve)
        #expect(h.codes.filter { $0 == "baseline.adopted" }.count == adoptions)
        if boosted {
            let factor = h.controller()?.appliedFactor ?? 1
            #expect(factor > 1 && h.table()?.matches(curve.scaled(by: factor), tolerance: 1e-6) == true)
        } else {
            #expect(h.table() == curve)
        }
    }

    /// Once WindowServer's new table is adopted at rest, our old write is no longer on screen: another writer that
    /// puts that old table back is a foreign writer, and the next arm captures its table instead of keeping the profile
    /// base as if it were our stale write (C-BOOST-18).
    @Test func ourOldTableRestoredByAnotherWriterIsForeign() async throws {
        let h = EngineHarness()
        await boostThenOff(h)
        h.gamma.changeBase(newBase, for: 1)
        h.signals.emit(.displaysReconfigured)
        await h.advance(.seconds(3))
        #expect(h.controller()?.baseline == newBase && h.controller()?.lastWrite == nil)
        h.gamma.foreignWrite(base, to: 1)                                   // the old table, from another writer
        #expect(await h.boost())
        #expect(h.controller()?.baseline == base && h.codes.contains("baseline.foreign"))
        #expect(!h.codes.contains("baseline.keptOverOwnWrite"))
    }

    /// A landing WindowServer refused (a trip's, or a shield's baseline write), then WindowServer's new base replaces
    /// our scaled table: nothing of ours is on screen any more, so the display leaves the safety ledger at once. The
    /// hang watchdog (real, as in `EngineWatchdogTests`, on a queue that always answers) stops pinging and the boost
    /// marker goes, at rest and after "off" (DESIGN.md §17; C-BOOST-18 with C-BOOST-1). Without that, no baseline
    /// write would ever follow to empty the entry.
    @Test(arguments: [false, true])
    func windowServersNewBaseOverAFailedLandingEmptiesTheLedger(shielded: Bool) async throws {
        let h = EngineHarness()
        h.engine.watchdog = HangWatchdog(writer: h.engine.writer, ledger: h.engine.ledger, journal: h.journal,
                                         pingInterval: .milliseconds(50), timeout: .seconds(60),
                                         pinged: DispatchQueue(label: "app.overbright.tests.rebase-at-rest.watchdog"))
        h.engine.watchdogEnabled = true
        await h.start()
        #expect(await h.boost())
        #expect(h.engine.watchdog.isActive && h.settings[EngineRecords.boostMarker] != nil)
        h.gamma.failNextWrite(with: .coreGraphics(code: 1000))
        if shielded {
            h.signals.snapshot.isScreenLocked = true
            h.signals.emit(.locked)
            #expect(h.phase() == .suspended(.shielded))
        } else {
            h.controller()?.fail(.repairBudgetExceeded)
            #expect(h.phase() == .failed(.repairBudgetExceeded))
        }
        #expect((h.liveFactor() ?? 1) > 1 && h.engine.ledger.isMarked(h.builtIn))     // the landing failed
        h.gamma.changeBase(newBase, for: 1)                                           // WindowServer's new table
        h.signals.emit(.colorProfileChanged)
        await h.advance(.seconds(2))
        #expect(h.table() == newBase && h.controller()?.baseline == newBase)
        #expect(h.engine.ledger.entries().isEmpty && h.settings[EngineRecords.boostMarker] == nil)
        #expect(!h.engine.watchdog.isActive)
        h.engine.setOn(false, source: .panel)
        h.engine.reduceNow()
        await h.advance(.seconds(1))
        #expect(h.table() == newBase && h.engine.ledger.entries().isEmpty)
        #expect(h.settings[EngineRecords.boostMarker] == nil && !h.engine.watchdog.isActive)
        h.engine.stopNow()
    }

    /// A calibration's fresh baseline never captures our old write either; the next reduction writes the new base.
    @Test func aDrivenSessionNeverCapturesOurOldWrite() async throws {
        let h = EngineHarness()
        await boostThenOff(h)
        h.gamma.failNextWrite(with: .coreGraphics(code: 1000))
        h.gamma.changeBase(newBase, for: 1, appliesNow: false)
        h.signals.emit(.colorProfileChanged)
        h.gamma.failNextWrite(with: .coreGraphics(code: 1000))       // the refresh's own retry fails too
        let controller = try #require(h.controller())
        #expect(controller.refreshBaseline() && controller.baseline == newBase && h.table() == base)
        await h.advance(.milliseconds(500))
        #expect(h.table() == newBase && controller.pendingRebase == nil)
    }
}
