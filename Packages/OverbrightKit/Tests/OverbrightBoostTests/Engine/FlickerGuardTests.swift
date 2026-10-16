// OverbrightBoostTests/Engine/FlickerGuardTests.swift — WCAG 2.3.1 safety (ARCHITECTURE.md §4.5 invariant 8, §5.8):
// the 500 ms rate limiter, the oscillation detector (4 non-user reversals in 10 s), the user and monotonic-headroom
// exemptions, and the engine's trip.
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct FlickerGuardTests {
    private func at(_ milliseconds: Int) -> MonotonicInstant { MonotonicInstant(sinceOrigin: .milliseconds(milliseconds)) }

    @Test func opposingTransitionsWaitFiveHundredMilliseconds() {
        var guardian = FlickerGuard()
        #expect(guardian.delay(before: .up, at: at(0)) == .zero)
        _ = guardian.record(.up, at: at(0), origin: .user)
        #expect(guardian.delay(before: .up, at: at(100)) == .zero)                    // same direction: no wait
        #expect(guardian.delay(before: .down, at: at(200)) == .milliseconds(300))
        #expect(guardian.delay(before: .down, at: at(500)) == .zero)
    }

    @Test func fourAutomaticReversalsInTenSecondsTrip() {
        var guardian = FlickerGuard()
        var tripped: [Bool] = []
        for (index, direction) in [FlickerGuard.Direction.up, .down, .up, .down, .up].enumerated() {
            tripped.append(guardian.record(direction, at: at(1_000 * index), origin: .automatic))
        }
        #expect(tripped == [false, false, false, false, true])
    }

    @Test func userReversalsNeverCount() {
        var guardian = FlickerGuard()
        for index in 0..<20 {
            let result = guardian.record(index.isMultiple(of: 2) ? .up : .down, at: at(600 * index), origin: .user)
            #expect(!result)
        }
        #expect(guardian.reversals.isEmpty)
    }

    @Test func reversalsOlderThanTheWindowExpire() {
        var guardian = FlickerGuard()
        for index in 0..<10 {
            let result = guardian.record(index.isMultiple(of: 2) ? .up : .down, at: at(4_000 * index), origin: .automatic)
            #expect(!result)
        }
    }

    @Test func monotonicHeadroomTrackingIsExempt() {
        var guardian = FlickerGuard()
        // The brightness keys move H in one direction: following it is not flicker.
        var h = 2.0
        for index in 0..<8 {
            h += 0.1
            guardian.noteHeadroom(h)
            let result = guardian.record(index.isMultiple(of: 2) ? .up : .down, at: at(600 * index), origin: .headroomTracking)
            #expect(!result)
        }
        #expect(guardian.headroomMovedMonotonically)
        // H wobbling up and down is not following: those clamps count.
        var wobbling = FlickerGuard()
        var trips: [Bool] = []
        for index in 0..<5 {
            for h in [2.0, 2.2, 2.0] { wobbling.noteHeadroom(h) }
            trips.append(wobbling.record(index.isMultiple(of: 2) ? .up : .down, at: at(600 * index), origin: .headroomTracking))
        }
        #expect(trips.last == true)
    }

    @Test func unexplainedAdoptionsCountAsReversals() {
        var guardian = FlickerGuard()
        var trips: [Bool] = []
        for second in 0..<4 { trips.append(guardian.recordReversal(at: at(1_000 * second))) }
        #expect(trips == [false, false, false, true])
        guardian.reset()
        #expect(guardian.reversals.isEmpty && guardian.lastDirection == nil)
    }

    /// The engine: a guard that flaps (heat at serious, on and off every second) trips the display into
    /// failed(oscillation) instead of pumping the brightness; Try Again clears it.
    @Test func flappingCapTripsTheDisplay() async throws {
        let h = EngineHarness(decide: GuardingReducer().decide)
        await h.start()
        #expect(await h.boost())
        await h.advance(.seconds(1))
        var tripped = false
        for _ in 0..<12 where !tripped {
            h.signals.snapshot.thermal = h.signals.snapshot.thermal == .serious ? .nominal : .serious
            await h.advance(.milliseconds(800))
            tripped = h.phase() == .failed(.oscillation)
        }
        #expect(tripped)
        #expect(h.everyTableAtBase && h.liveTriggers().isEmpty)
        #expect(h.codes.contains("flicker.trip"))
        h.signals.snapshot.thermal = .nominal
        h.engine.retry(h.builtIn)
        #expect(await h.boost())
    }

    /// No two opposing transitions on a display start within 500 ms, even for quick user reversals: the reversal is
    /// coalesced, the screen holds, and the new ramp starts once the interval has passed.
    @Test func quickUserReversalWaits() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        await h.advance(.seconds(1))
        h.engine.setLevel(LevelPreset.max.position, for: h.builtIn, source: .panel)
        await h.advance(.milliseconds(100))
        let held = h.writes().count
        let heldGain = try #require(h.controller()?.appliedGain)
        h.engine.setLevel(LevelPreset.indoor.position, for: h.builtIn, source: .panel)
        await h.advance(.milliseconds(390))
        #expect(h.writes().count == held)
        #expect(h.controller()?.appliedGain == heldGain && heldGain > pow(ReferenceReducer.defaultTop, 0.5))
        await h.advance(.milliseconds(450))
        #expect(abs((h.displayStatus()?.appliedGain ?? 0) - pow(ReferenceReducer.defaultTop, 0.25)) < 1e-9)
    }
}
