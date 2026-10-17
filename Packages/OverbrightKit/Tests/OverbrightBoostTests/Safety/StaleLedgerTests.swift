// OverbrightBoostTests/Safety/StaleLedgerTests.swift — a scaled write that throws inside WindowServer keeps its ledger
// entry (`TableWriter` marks the display before the write, §4.5 invariant 9, and the table may have taken it), so every
// landing treats "the ledger holds this display" as "the table may be off its baseline" and writes the baseline, which
// empties the entry. Otherwise the hang watchdog and the boost marker, which follow the ledger (D7, §4.6), would stay on
// while nothing is scaled and the master is off (§7.1, DESIGN.md §17; WP14 C-BOOST-1 regression). While WindowServer
// refuses that baseline too, the trigger stays with the table the failed write may have left (§4.5 invariant 2) until
// the at-rest retry writes it. The watchdog is real,
// as in `EngineWatchdogTests`, but pings a queue nobody stalls with a timeout no run reaches, so it never fires; whether
// it runs follows the ledger synchronously (its occupancy observer runs inside the ledger lock). The engine runs on the
// manual clock. Only the fakes are written.
import Dispatch
import Foundation
import OverbrightCore
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite(.serialized) struct StaleLedgerTests {
    private static let failure = GammaError.coreGraphics(code: 1000)

    /// An engine whose real watchdog pings a queue of its own (never stalled: it never fires).
    private func harness(reducer: ReferenceReducer = ReferenceReducer()) -> EngineHarness {
        let h = EngineHarness(reducer: reducer)
        h.engine.watchdog = HangWatchdog(writer: h.engine.writer, ledger: h.engine.ledger, journal: h.journal,
                                         pingInterval: .milliseconds(50), timeout: .seconds(3_600),
                                         pinged: DispatchQueue(label: "app.overbright.tests.stale-ledger"))
        h.engine.watchdogEnabled = true
        return h
    }

    /// Nothing is left of the display's scaling: no ledger entry, no boost marker, no watchdog timer, the base on
    /// screen, no window and no task.
    private func expectNothingRuns(_ h: EngineHarness, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(h.engine.ledger.entries().isEmpty, "ledger \(h.engine.ledger.markedDisplays)", sourceLocation: sourceLocation)
        #expect(!h.engine.watchdog.isActive, "the hang watchdog still runs", sourceLocation: sourceLocation)
        #expect(h.settings[EngineRecords.boostMarker] == nil, "the boost marker is set", sourceLocation: sourceLocation)
        #expect(h.everyTableAtBase, sourceLocation: sourceLocation)
        #expect(h.triggers.openWindowCount == 0, sourceLocation: sourceLocation)
        #expect(h.engine.activeTaskNames == [], sourceLocation: sourceLocation)
        #expect(h.orderViolations == [], sourceLocation: sourceLocation)
    }

    private func isGating(_ h: EngineHarness) -> Bool {
        if case .gating = h.phase() { return true }
        return false
    }

    /// What a write WindowServer took although it reported an error leaves: our display marked, a scaled table on screen.
    private func markAsIfAScaledWriteThrew(_ h: EngineHarness, factor: Double) throws {
        let controller = try #require(h.controller())
        let baseline = try #require(controller.baseline)
        h.engine.ledger.markScaled(controller.ref, baseline: baseline)
        h.gamma.foreignWrite(baseline.scaled(by: factor), to: controller.ref.id)
    }

    // MARK: A real failed write from neutral

    /// The sequence that found it (WP14 leftovers): the first dim step from neutral throws, the user returns to
    /// Standard and turns off. The landing after the failed step writes the baseline over whatever WindowServer took,
    /// so the entry goes at once, and off leaves nothing running.
    @Test func aFailedFirstDimStepLeavesNothingRunningOnceOff() async {
        let h = harness()
        await h.start()
        h.gamma.failNextWrite(with: Self.failure)
        h.engine.setLevel(LevelPosition(-0.5), for: h.builtIn, source: .panel)
        await h.advance(.milliseconds(30), step: .milliseconds(5))
        #expect(h.codes.contains("write.failed"))
        // The only write so far is the landing's baseline: the failed step was scaled, so the ledger held the display.
        #expect(h.writes().map(\.table) == h.base().map { [$0] })
        #expect(h.engine.ledger.entries().isEmpty && !h.engine.watchdog.isActive)
        h.engine.setLevel(.standard, for: h.builtIn, source: .panel)
        h.engine.setOn(false, source: .panel)
        await h.advance(.seconds(10))
        #expect(h.phase() == .idle)
        expectNothingRuns(h)
        h.engine.stopNow()
    }

    /// The same for the first step of a boost ramp: the gate passed, nothing is scaled yet, and that step throws. A
    /// top of ×2.5 in Peak makes the first step a scaled write (a step below ×1.005 writes the baseline, §5.4).
    @Test func aFailedFirstBoostStepLeavesNothingRunningOnceOff() async {
        let h = harness(reducer: ReferenceReducer(top: 2.5))
        h.setPreferences { $0.capMode = .peak }
        await h.start()
        h.engine.setLevel(LevelPosition(1), for: h.builtIn, source: .panel)
        #expect(await h.advance(until: { isGating(h) }, step: .milliseconds(5)))
        #expect(h.writes().isEmpty)                                       // no write happens while arming or gating
        h.gamma.failNextWrite(with: Self.failure)
        #expect(await h.advance(until: { h.codes.contains("write.failed") }, step: .milliseconds(5)))
        #expect(h.writes().map(\.table) == h.base().map { [$0] })        // the landing, after a scaled step
        #expect(h.engine.ledger.entries().isEmpty && !h.engine.watchdog.isActive)
        h.engine.setOn(false, source: .panel)                             // before the 250 ms retry
        await h.advance(.seconds(10))
        #expect(h.phase() == .idle)
        expectNothingRuns(h)
        h.engine.stopNow()
    }

    /// A calibration's first factor above Standard throws: the session ends at Standard, and its landing writes the
    /// baseline because the ledger still holds the display (`writeCalibrationFactor` marks it like every scaled write).
    @Test func aFailedCalibrationFactorFromStandardLeavesNothingRunning() async throws {
        let h = harness()
        await h.start()
        let session = try #require(h.engine.beginCalibration(of: h.builtIn))
        #expect(await h.advance(until: { session.state == .ready }, limit: .seconds(30), step: .milliseconds(50)))
        #expect(h.engine.ledger.entries().isEmpty)
        h.gamma.failNextWrite(with: Self.failure)
        session.showComparison(boosted: true)                             // ×1.3 light: the first scaled write
        #expect(session.state == .aborted(.writeRefused))
        await h.advance(.seconds(1))
        expectNothingRuns(h)
        h.engine.stopNow()
    }

    // MARK: Every landing path, with the entry such a write leaves

    /// A display that prepares a boost has nothing applied; while the ledger holds it, the disarm writes the baseline
    /// before the trigger goes (§4.5 invariant 2) instead of only removing the windows.
    @Test func theDisarmOfAnUnscaledDisplayWritesTheBaselineWhileMarked() async throws {
        let h = harness()
        await h.start()
        h.engine.setOn(true, source: .panel)
        #expect(await h.advance(until: { isGating(h) }, step: .milliseconds(5)))
        try markAsIfAScaledWriteThrew(h, factor: 1.2)
        #expect(h.engine.watchdog.isActive)
        h.engine.setOn(false, source: .panel)                             // the reduction disarms at once
        #expect(h.phase() == .idle)
        expectNothingRuns(h)
        #expect(h.writes().last?.table == h.base())
        h.engine.stopNow()
    }

    /// Back to Standard from a display with nothing applied does the same.
    @Test func backToStandardOfAnUnscaledDisplayWritesTheBaselineWhileMarked() async throws {
        let h = harness()
        await h.start()
        h.engine.setOn(true, source: .panel)
        #expect(await h.advance(until: { isGating(h) }, step: .milliseconds(5)))
        try markAsIfAScaledWriteThrew(h, factor: 1.2)
        h.engine.returnToStandard(source: .shortcut)
        #expect(h.phase() == .idle)
        expectNothingRuns(h)
        h.engine.stopNow()
    }

    // MARK: A refused baseline while the ledger marks the display

    /// The disarm with nothing applied, when WindowServer refuses its baseline too: the scaled table that the failed
    /// write may have left keeps the trigger's EDR request (§4.5 invariant 2, as `keepsWindowsAfterFailedLanding` does
    /// for our own last write), and the at-rest retry of the reduction the disarm asks for removes it after the
    /// baseline.
    @Test func aRefusedDisarmBaselineKeepsTheTriggerOfAMarkedDisplayUntilTheRetry() async throws {
        let h = harness()
        await h.start()
        h.engine.setOn(true, source: .panel)
        #expect(await h.advance(until: { isGating(h) }, step: .milliseconds(5)))
        let windows = h.triggers.openWindowCount
        #expect(windows > 0)
        try markAsIfAScaledWriteThrew(h, factor: 1.2)
        h.gamma.failNextWrite(with: Self.failure)
        h.engine.setOn(false, source: .panel)                             // the reduction disarms at once
        #expect(h.phase() == .idle)
        #expect(h.codes.contains("baseline.writeFailed") && h.codes.contains("order.windowsKept"))
        #expect(h.triggers.openWindowCount == windows)                   // ×1.2 is still on screen
        #expect(h.engine.ledger.isMarked(h.builtIn))
        #expect(h.orderViolations == [])
        await h.settle()                                                  // the reduction the disarm asked for
        #expect(h.codes.contains("baseline.retried"))
        expectNothingRuns(h)
        h.engine.stopNow()
    }

    /// Back to Standard does the same: the trigger waits for the landing its reduction retries at rest.
    @Test func aRefusedBackToStandardBaselineKeepsTheTriggerOfAMarkedDisplayUntilTheRetry() async throws {
        let h = harness()
        await h.start()
        h.engine.setOn(true, source: .panel)
        #expect(await h.advance(until: { isGating(h) }, step: .milliseconds(5)))
        try markAsIfAScaledWriteThrew(h, factor: 1.2)
        h.gamma.failNextWrite(with: Self.failure)
        h.engine.returnToStandard(source: .shortcut)
        #expect(h.phase() == .idle)
        expectNothingRuns(h)                                              // no removal while ×1.2 was on screen
        let kept = try #require(h.codes.firstIndex(of: "order.windowsKept"))
        let retried = try #require(h.codes.firstIndex(of: "baseline.retried"))
        #expect(kept < retried)
        h.engine.stopNow()
    }

    /// A marked display whose table reads back as the baseline (WindowServer did not take the failed write) has
    /// nothing on screen that needs the EDR request: the trigger goes with the disarm, and the retry empties the entry.
    @Test func aRefusedBaselineLetsTheTriggerGoWhenTheTableIsAtItsBaseline() async throws {
        let h = harness()
        await h.start()
        h.engine.setOn(true, source: .panel)
        #expect(await h.advance(until: { isGating(h) }, step: .milliseconds(5)))
        let controller = try #require(h.controller())
        h.engine.ledger.markScaled(controller.ref, baseline: try #require(controller.baseline))
        h.gamma.failNextWrite(with: Self.failure)
        h.engine.setOn(false, source: .panel)
        #expect(h.codes.contains("baseline.writeFailed") && !h.codes.contains("order.windowsKept"))
        #expect(h.triggers.openWindowCount == 0)
        #expect(h.engine.ledger.isMarked(h.builtIn))
        await h.settle()
        #expect(h.codes.contains("baseline.retried"))
        expectNothingRuns(h)
        h.engine.stopNow()
    }

    /// A display at rest whose ledger entry outlived a failed write: the next reduction writes the baseline
    /// (`retryLandingAtRest`), as it does for a landing that failed.
    @Test func aDisplayAtRestWritesTheBaselineWhileMarked() async throws {
        let h = harness()
        await h.start()
        h.engine.setLevel(LevelPosition(-0.5), for: h.builtIn, source: .panel)
        #expect(await h.advance(until: { h.phase() == .dimmed }))
        h.engine.setLevel(.standard, for: h.builtIn, source: .panel)
        h.engine.setOn(false, source: .panel)
        #expect(await h.advance(until: { h.phase() == .idle && h.engine.ledger.entries().isEmpty }))
        try markAsIfAScaledWriteThrew(h, factor: 0.8)
        #expect(h.engine.watchdog.isActive)
        h.engine.setOn(false, source: .menu)                              // any reduction
        #expect(h.codes.contains("baseline.retried"))
        expectNothingRuns(h)
        h.engine.stopNow()
    }

    /// The baseline write of a marked display that has no baseline of its own (Reset Display Colors forgets it) is the
    /// ledger's baseline: what the hang watchdog would write.
    @Test func aMarkedDisplayWithoutABaselineLandsOnTheLedgersBaseline() async throws {
        let h = harness()
        await h.start()
        h.engine.setLevel(LevelPosition(-0.5), for: h.builtIn, source: .panel)
        #expect(await h.advance(until: { h.phase() == .dimmed }))
        h.engine.setLevel(.standard, for: h.builtIn, source: .panel)
        h.engine.setOn(false, source: .panel)
        #expect(await h.advance(until: { h.phase() == .idle && h.engine.ledger.entries().isEmpty }))
        try markAsIfAScaledWriteThrew(h, factor: 0.8)
        let controller = try #require(h.controller())
        controller.baseline = nil
        #expect(controller.writeBaselineNow())
        expectNothingRuns(h)
        h.engine.stopNow()
    }
}
