// OverbrightBoostTests/Calibration/CalibrationAbortTests.swift — every early end returns the display to Standard at once
// and stops all work (ARCHITECTURE.md §10.7: auto-abort on occlusion, lock, headroom drop or 60 s; DESIGN.md §9: Esc
// always restores at once).
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct CalibrationAbortTests {
    /// The session ended for `reason`, at Standard with the trigger gone, and nothing moves afterwards.
    private func expectEnded(_ c: CalibrationRig, _ reason: CalibrationAbortReason) async {
        #expect(c.controller.state == .aborted(reason))
        #expect(c.controller.currentFactor == 1 && !c.controller.isSweepPausedAtLimit)
        #expect(c.driver.calls.last == .returnToStandard && !c.driver.isArmed)
        #expect(c.rig.gamma.table(of: c.driver.display.id) == c.driver.baseline)
        #expect(c.codes.contains("calibration.aborted.\(reason.rawValue)"))
        #expect(c.endings == 1 && c.stateAtEnd == .aborted(reason))
        let calls = c.driver.calls.count
        await c.advance(.seconds(10))
        #expect(c.driver.calls.count == calls)
        c.controller.startSweep()
        c.controller.showComparison(boosted: true)
        #expect(c.driver.calls.count == calls)
    }

    /// A sweep running at about ×1.3.
    private func sweeping() async -> CalibrationRig {
        let c = CalibrationRig()
        #expect(await c.ready())
        #expect(await c.sweep(to: 1.3))
        #expect(c.controller.currentFactor > 1)
        return c
    }

    @Test func escapeRestoresAtOnce() async throws {
        let c = await sweeping()
        c.controller.cancel()
        #expect(c.controller.currentFactor == 1)                       // before any time passes
        await expectEnded(c, .cancelled)
        // An interrupted sweep records nothing (§11.1 #35): an earlier record stays.
        #expect(c.controller.finish(brighter: true) == nil)
        #expect(c.endings == 1)
    }

    /// An abort mid-sweep never replaces a valid earlier record (§11.1 #35, C-BOOST-19): `finish` returns nil, which the
    /// calibration window does not store. Every early end of the sweep counts: Esc, a lock, occlusion, a headroom drop.
    @Test(arguments: [CalibrationAbortReason.cancelled, .shielded, .occluded, .headroomDropped, .writeRefused])
    func anInterruptedSweepKeepsTheEarlierRecord(_ reason: CalibrationAbortReason) async throws {
        let earlier = CalibrationRecord(outcome: .encoded, mechanism: .table, mergeFactor: 1.6, estimatedExponent: 2.4,
                                        measuredSDRWhiteNits: nil, headroomAtTest: 2.667, potentialAtTest: 16,
                                        osBuild: DisplayFixture.ownerMachine.osBuild, measuredAt: Date())
        var preferences = DisplayPreferences()
        preferences.calibration = earlier
        let c = await sweeping()
        c.controller.setMeasuredSDRWhite(nits: 600)
        c.controller.abort(reason)
        if let record = c.controller.finish(brighter: true) { preferences.calibration = record }   // the window's store
        #expect(preferences.calibration == earlier)
    }

    /// An abort after the sweep ended with a mark keeps what was measured: the mark decides, unconfirmed linear stays
    /// inconclusive.
    @Test func anAbortAfterTheMarkStillRecordsIt() async throws {
        let c = CalibrationRig()
        #expect(await c.ready())
        #expect(await c.sweep(to: 1.6))
        c.controller.markMerged()
        c.controller.handle(.locked)
        #expect(c.controller.state == .aborted(.shielded))
        #expect(try #require(c.controller.finish(brighter: true)).outcome == .encoded)

        let d = CalibrationRig()
        #expect(await d.ready())
        #expect(await d.sweep(to: 3.0, continuingPastThePause: true))
        d.controller.markMerged()
        d.controller.showLinearConfirmation()
        await d.advance(.seconds(2))
        d.controller.answerLinearConfirmation(distinguishable: true)
        d.controller.cancel()
        #expect(try #require(d.controller.finish(brighter: true)).outcome == .linear)
    }

    @Test(arguments: [SystemEvent.locked, .screensaverStarted, .willSleep, .screensDidSleep, .sessionResigned])
    func anyShieldEndsTheSession(_ event: SystemEvent) async {
        let c = await sweeping()
        c.controller.handle(event)
        await expectEnded(c, .shielded)
    }

    @Test func otherEventsDoNotEndIt() async {
        let c = await sweeping()
        c.controller.handle(.displayRemoved(99))
        c.controller.handle(.activeSpaceChanged)
        c.controller.handle(.unlocked)
        #expect(c.controller.state == .sweeping)
        c.controller.handle(.displayRemoved(c.driver.display.id))
        await expectEnded(c, .displayGone)
    }

    @Test func occlusionEndsTheSession() async {
        let c = await sweeping()
        c.controller.setOccluded(false)
        #expect(c.controller.state == .sweeping)
        c.controller.setOccluded(true)
        await expectEnded(c, .occluded)
    }

    @Test func aHeadroomDropEndsTheSweep() async {
        let c = await sweeping()
        c.rig.headroom.setGrant(2.4, for: c.key)                       // 90 % of 2.667: the brightness keys moved
        await c.advance(.milliseconds(400))
        await expectEnded(c, .headroomDropped)
    }

    @Test func aHeadroomDropEndsTheComparisonAndTheConfirmation() async {
        let c = CalibrationRig()
        #expect(await c.ready())
        c.controller.showComparison(boosted: true)
        c.rig.headroom.setGrant(1.5, for: c.key)
        await c.advance(.milliseconds(400))
        await expectEnded(c, .headroomDropped)

        let d = CalibrationRig()
        #expect(await d.ready())
        #expect(await d.sweep(to: 3.0, continuingPastThePause: true))
        d.controller.markMerged()
        d.controller.showLinearConfirmation()
        d.rig.headroom.setGrant(2.0, for: d.key)
        await d.advance(.milliseconds(400))
        await expectEnded(d, .headroomDropped)
    }

    @Test func sixtySecondsEndTheSweepEvenWhilePaused() async {
        let c = CalibrationRig()
        #expect(await c.ready())
        c.controller.startSweep()
        #expect(await c.advance(until: { c.controller.isSweepPausedAtLimit }, limit: .seconds(30)))
        await c.advance(.seconds(30))
        #expect(c.controller.state == .sweeping)
        #expect(await c.advance(until: { c.controller.state != .sweeping }, limit: .seconds(30)))
        await expectEnded(c, .timeLimit)
    }

    @Test func aRefusedWriteEndsTheSession() async {
        let c = CalibrationRig()
        #expect(await c.ready())
        c.driver.refusesFactors = true
        c.controller.startSweep()
        await expectEnded(c, .writeRefused)
    }

    @Test func noGrantMeansNoExtraRange() async {
        let c = CalibrationRig()
        c.rig.headroom.update(c.key) { $0.respondingStrategies = [] }
        c.controller.begin()
        #expect(await c.advance(until: { c.controller.state != .preparing }, limit: .seconds(60)))
        await expectEnded(c, .noExtraRange)
        #expect(c.rig.factory.made.count == 7 && c.rig.factory.openWindowCount == 0)
    }

    @Test func aDisplayWithoutExtraRangeIsNotArmed() async {
        let c = CalibrationRig(.mpg322uxHDROff, key: DisplayFixture.Keys.mpg322ux)
        c.controller.begin()
        #expect(await c.advance(until: { c.controller.state != .preparing }, limit: .seconds(5)))
        await expectEnded(c, .noExtraRange)
        #expect(c.rig.factory.made.isEmpty)
    }

    @Test func aShieldWhilePreparingStopsTheArming() async {
        let c = CalibrationRig()
        c.controller.begin()
        await c.advance(.milliseconds(600))
        #expect(c.controller.state == .preparing && c.driver.isArmed)
        c.controller.handle(.locked)
        await expectEnded(c, .shielded)
        #expect(c.rig.factory.made.count == 1)
    }

    @Test func cancellingBeforeTheStartTouchesNothing() {
        let c = CalibrationRig()
        c.controller.cancel()
        #expect(c.controller.state == .aborted(.cancelled) && c.driver.calls.isEmpty && c.endings == 1)
        #expect(c.controller.finish(brighter: nil) == nil)
    }
}
