// OverbrightBoostTests/Calibration/CalibrationEngineTests.swift — a calibration through the engine's real
// `DisplayController` and `TableWriter` (ARCHITECTURE.md §5.2, §4.6, §4.7; DESIGN.md §9): the sweep passes 0.97 × H
// and can record a linear result, a hang restore or the engine's own stops end the session and nothing is scaled again
// until a new one, and a lost trigger ends the session (or the self-test on that display). Only the fakes are
// written.
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct CalibrationEngineTests {
    private let grant = 1600.0 / 600

    /// A started engine with a calibration of the built-in display that reached `.ready`.
    private func readySession(_ h: EngineHarness) async throws -> any CalibrationSession {
        await h.start()
        let session = try #require(h.engine.beginCalibration(of: h.builtIn))
        #expect(await h.advance(until: { session.state == .ready }, limit: .seconds(30), step: .milliseconds(50)))
        return session
    }

    /// Sweeps until the factor reaches `factor` (past the pause when asked); the highest live table factor seen.
    @discardableResult
    private func sweep(_ session: any CalibrationSession, _ h: EngineHarness, to factor: Double,
                       pastThePause: Bool = false) async -> Double {
        session.startSweep()
        var highest = 1.0
        _ = await h.advance(until: {
            if pastThePause, session.isSweepPausedAtLimit { session.continueSweep() }
            highest = max(highest, h.liveFactor() ?? 1)
            return session.currentFactor >= factor - 1e-9 || session.state != .sweeping
                || (!pastThePause && session.isSweepPausedAtLimit)
        }, limit: .seconds(60), step: .milliseconds(100))
        return max(highest, h.liveFactor() ?? 1)
    }

    /// The table factors of our writes since `index`, over the display's base.
    private func factors(_ h: EngineHarness, since index: Int) -> [Double] {
        guard let base = h.base() else { return [] }
        return h.writes().dropFirst(index).compactMap { EngineHarness.factor(of: $0.table, over: base) }
    }

    // MARK: The sweep through the real writer (C-BOOST-5)

    /// On a table that really works in linear light the merge comes near 3.00 at H 2.667: the sweep passes 0.97 × H
    /// (2.587) through `TableWriter`, the mark is a linear candidate, and the confirmation records `.linear`.
    @Test func theSweepPassesZeroPointNineSevenHAndCanRecordLinear() async throws {
        let h = EngineHarness()
        let session = try await readySession(h)
        let highest = await sweep(session, h, to: 3.0, pastThePause: true)
        #expect(session.state == .sweeping && highest > FactorMath.headroomMargin * grant + 0.3)
        session.markMerged()
        guard case .swept(_, true) = session.state else {
            Issue.record("expected the linear confirmation, got \(session.state)")
            return
        }
        session.showLinearConfirmation()
        #expect(abs((h.liveFactor() ?? 0) - FactorMath.headroomMargin * grant) < 1e-3)
        await h.advance(.seconds(2), step: .milliseconds(100))
        session.answerLinearConfirmation(distinguishable: true)
        let record = try #require(session.finish(brighter: true))
        #expect(record.outcome == .linear)
        #expect(!h.codes.contains("interlock.refusedCalibration"))
        #expect(!h.codes.contains("calibration.aborted.writeRefused"))
        #expect(h.everyTableAtBase && h.liveTriggers().isEmpty && h.engine.ledger.entries().isEmpty)
    }

    // MARK: Hangs and the engine's own stops (C-BOOST-8)

    /// The hang watchdog restores the baselines mid-sweep: the next step is refused by the stale epoch, the session
    /// ends at Standard, and nothing is scaled again until a new session starts (which stamps the new epoch).
    @Test func aHangRestoreEndsTheSweepUntilANewSession() async throws {
        let h = EngineHarness()
        let session = try await readySession(h)
        await sweep(session, h, to: 1.2)
        #expect((h.liveFactor() ?? 1) > 1.15)
        let restored = EmergencyRestore.run(writer: h.engine.writer, ledger: h.engine.ledger)
        #expect(restored.displays == 1 && h.everyTableAtBase)
        let writes = h.writes().count
        await h.advance(.seconds(2), step: .milliseconds(100))
        #expect(session.state == .aborted(.writeRefused) && h.engine.calibrationSession == nil)
        #expect(factors(h, since: writes).allSatisfy { $0 <= 1 + 1e-6 })
        #expect(h.everyTableAtBase && h.liveTriggers().isEmpty && h.engine.ledger.entries().isEmpty)

        let next = try #require(h.engine.beginCalibration(of: h.builtIn))
        #expect(await h.advance(until: { next.state == .ready }, limit: .seconds(30), step: .milliseconds(50)))
        await sweep(next, h, to: 1.1)
        #expect((h.liveFactor() ?? 1) > 1.05)
        next.cancel()
        #expect(h.everyTableAtBase)
    }

    /// Quit, the ramped stop, the self-test and Reset Display Colors end a running calibration first: the display is at
    /// Standard, `onEnd` ran (the session is released), and its sweep never writes again.
    @Test(arguments: [0, 1, 2, 3])
    func theEngineEndsARunningCalibration(_ path: Int) async throws {
        let h = EngineHarness()
        let session = try await readySession(h)
        await sweep(session, h, to: 1.2)
        switch path {
        case 0:
            h.engine.stopNow()
        case 1:
            async let stopped: Void = h.engine.stop()
            await h.advance(.milliseconds(500))
            await stopped
        case 2:
            async let report = h.engine.runSelfTest(SelfTestOptions(secondsPerStrategy: 1))
            await h.settle()
            #expect(session.state == .aborted(.cancelled))
            await h.advance(.seconds(20), step: .milliseconds(50))
            _ = await report
        default:
            async let outcome = h.engine.rescueDisplayColors()
            await h.advance(.seconds(5), step: .milliseconds(50))
            _ = await outcome
        }
        #expect(session.state == .aborted(.cancelled) && h.engine.calibrationSession == nil)
        let writes = h.writes().count
        await h.advance(.seconds(2), step: .milliseconds(100))
        #expect(factors(h, since: writes).allSatisfy { $0 <= 1 + 1e-6 })
        #expect(h.everyTableAtBase && h.liveTriggers().isEmpty)
    }

    // MARK: A lost trigger (C-BOOST-9)

    /// AppKit moved the session's trigger to another screen: it is removed at once (it must never request EDR there)
    /// and the session ends with the display at Standard.
    @Test func aCalibrationTriggerMovedToAnotherScreenEndsTheSession() async throws {
        let h = EngineHarness()
        let session = try await readySession(h)
        await sweep(session, h, to: 1.2)
        let trigger = try #require(h.liveTriggers().first)
        h.triggers.moveWindows(on: h.builtIn, toScreen: 99)
        #expect(trigger.isRemoved && h.liveTriggers().isEmpty)
        #expect(session.state == .aborted(.displayGone) && h.engine.calibrationSession == nil)
        #expect(h.everyTableAtBase && h.codes.contains("trigger.movedScreen"))
    }

    /// The session's trigger was hidden: the session ends with the display at Standard.
    @Test func anOccludedCalibrationTriggerEndsTheSession() async throws {
        let h = EngineHarness()
        let session = try await readySession(h)
        await sweep(session, h, to: 1.2)
        h.triggers.setOccluded(true, on: h.builtIn)
        #expect(session.state == .aborted(.occluded) && h.engine.calibrationSession == nil)
        #expect(h.everyTableAtBase && h.liveTriggers().isEmpty)
    }

    /// A self-test trigger moved to another screen is removed at once and that display's measurement ends there.
    @Test func aSelfTestTriggerMovedToAnotherScreenStopsThatDisplay() async throws {
        let h = EngineHarness()
        await h.start()
        async let running = h.engine.runSelfTest(SelfTestOptions(everyStrategy: true, secondsPerStrategy: 5))
        #expect(await h.advance(until: { !h.liveTriggers().isEmpty }, limit: .seconds(5), step: .milliseconds(50)))
        h.triggers.moveWindows(on: h.builtIn, toScreen: 99)
        #expect(h.liveTriggers().isEmpty)
        await h.advance(.seconds(5), step: .milliseconds(50))
        let made = h.triggers.made.count
        await h.advance(.seconds(30), step: .milliseconds(50))
        let report = await running
        #expect(h.triggers.made.count == made)                          // no further rung on that display
        #expect(h.codes.contains("selftest.displayStopped") && report.displays[h.builtIn.rawValue] != nil)
        #expect(h.everyTableAtBase && h.liveTriggers().isEmpty)
    }
}
