// OverbrightBoostTests/Engine/MinorPublishTests.swift — DESIGN.md §17's "allowed-now marker ≤ 4 Hz": a status change of
// minor fields only (readings, and the applied gain while a ramp runs) is published at most every
// `minorPublishInterval` on the trailing edge; a major change (phase, target, decision, symbol, banner, `lastChange`,
// `pendingLowLevel`, on, ready, pause, auto-off, the display set) publishes at once with the latest minor values; stop
// leaves no task (§4.5 invariant 4). Counted with the DEBUG `publishCount` probe.
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct MinorPublishTests {
    /// Boosted at Bright room with the full grant: H can move between 2.55 and 2.75 without a lowering (applied stays
    /// below 0.98 × H) or a recovery raise (the target is already applied), so only the reading changes.
    private func boosted() async -> EngineHarness {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        await h.advance(.seconds(4))
        return h
    }

    /// 2 s of screen-parameters notifications every 10 ms while H moves: every notification takes a fresh reading,
    /// but the status is republished at most 4 times a second.
    @Test func readingOnlyChangesPublishAtMostFourTimesASecond() async throws {
        let h = await boosted()
        let phase = h.phase()
        let published = h.engine.publishCount
        for step in 0..<200 {
            h.scripted.setOverride(2.55 + 0.001 * Double(step), for: h.builtIn)
            h.signals.emit(.screenParametersChanged)
            await h.advance(.milliseconds(10))
        }
        #expect(h.phase() == phase)
        let count = h.engine.publishCount - published
        #expect(count >= 6 && count <= 9, "\(count) publishes in 2 s")
        // The last value lands at most 250 ms after the last change.
        await h.advance(EngineTiming.minorPublishInterval)
        let shown = try #require(h.displayStatus()?.lastReading?.current)
        let fresh = try #require(h.controller()?.lastReading?.current)
        #expect(abs(shown - fresh) < DisplayController.publishedReadingStep)
        #expect(!h.engine.activeTaskNames.contains("minorPublish"))
    }

    /// A major change publishes at once, carrying the reading that was waiting.
    @Test func aMajorChangePublishesAtOnceWithTheLatestReading() async throws {
        let h = await boosted()
        h.scripted.setOverride(2.6, for: h.builtIn)
        h.signals.emit(.screenParametersChanged)
        #expect(h.engine.activeTaskNames.contains("minorPublish"))
        let published = h.engine.publishCount
        h.engine.pause(until: nil, source: .panel)
        #expect(h.engine.publishCount > published)
        #expect(h.engine.status.pausedUntil != nil)
        #expect(h.displayStatus()?.lastReading?.current == 2.6)
        #expect(!h.engine.activeTaskNames.contains("minorPublish"))
    }

    /// A ramp's end (a phase change) publishes at once with its final gain; a shield is visible when `emit` returns.
    @Test func phaseChangesNeverWait() async throws {
        let h = EngineHarness(reducer: ReferenceReducer(top: 2.587))
        h.setPreferences { $0.capMode = .peak }
        await h.start()
        #expect(await h.boost())
        await h.advance(.seconds(4))
        h.engine.setLevel(LevelPreset.max.position, for: h.builtIn, source: .panel)
        #expect(h.phase() == .ramping)
        #expect(await h.advance(until: { h.controller()?.phase == .boosted }, step: .milliseconds(5)))
        #expect(h.phase() == .boosted)
        #expect(h.displayStatus()?.appliedGain == h.controller()?.appliedGain)
        h.signals.snapshot.isScreenLocked = true
        h.signals.emit(.locked)
        #expect(h.phase()?.isSuspended == true)
        #expect(h.displayStatus()?.appliedGain == 1)
    }

    /// The minor/major split itself.
    @Test func onlyReadingsAndRampGainsAreMinor() async throws {
        let h = await boosted()
        let published = h.engine.status
        let shown = try #require(published.displays.first)
        func with(_ change: (inout DisplayStatus) -> Void) -> BoostStatus {
            var next = published
            change(&next.displays[0])
            return next
        }
        let reading = HeadroomReading(display: 1, current: 2.0, potential: 16, reference: 0, time: h.time.now)
        #expect(BoostEngine.differsInMinorFieldsOnly(published, with { $0.lastReading = reading }))
        #expect(BoostEngine.differsInMinorFieldsOnly(published, with { $0.lastGrant = 2.5 }))
        #expect(!BoostEngine.differsInMinorFieldsOnly(published, with { $0.appliedGain = shown.appliedGain + 0.1 }))
        #expect(!BoostEngine.differsInMinorFieldsOnly(published, with { $0.phase = .ramping }))
        var ramping = published
        ramping.displays[0].phase = .ramping
        var step = ramping
        step.displays[0].appliedGain += 0.05
        step.displays[0].appliedFactor += 0.02
        #expect(BoostEngine.differsInMinorFieldsOnly(ramping, step))
        var off = published
        off.isOn = false
        #expect(!BoostEngine.differsInMinorFieldsOnly(published, off))
        var pending = published
        pending.symbol = .paused
        #expect(!BoostEngine.differsInMinorFieldsOnly(published, pending))
        var none = published
        none.displays = []
        #expect(!BoostEngine.differsInMinorFieldsOnly(published, none))
    }

    /// Stopping the engine publishes what was waiting and leaves no task.
    @Test func stopLeavesNoWaitingPublish() async throws {
        let h = await boosted()
        h.scripted.setOverride(2.6, for: h.builtIn)
        h.signals.emit(.screenParametersChanged)
        #expect(h.engine.activeTaskNames.contains("minorPublish"))
        h.engine.stopNow()
        #expect(h.engine.activeTaskCount == 0)
        let published = h.engine.publishCount
        await h.advance(.seconds(1))
        #expect(h.engine.publishCount == published)
    }
}
