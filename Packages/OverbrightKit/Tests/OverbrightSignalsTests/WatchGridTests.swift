// OverbrightSignalsTests/WatchGridTests.swift — Signals' full-screen and playback watch waits for the shared 2 s grid of
// the one time source (ARCHITECTURE.md D29; D28's own timer stays): every tick lands on a multiple of 2 s since the
// origin, the first one at most 2 s after the watch starts, so it shares the wake-up of the other 2 s activities. On the
// manual clock, which moves only when a test advances it (§9.1).
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightSignals

@MainActor @Suite struct WatchGridTests {
    private let interval = SignalsMonitor.watchInterval

    private func at(_ duration: Duration) -> MonotonicInstant { MonotonicInstant(sinceOrigin: duration) }

    /// Advances the manual clock in 100 ms steps for `duration` and returns the instants of the window-list reads.
    private func reads(_ harness: SignalsHarness, for duration: Duration) async -> [MonotonicInstant] {
        var seen: [MonotonicInstant] = []
        var count = harness.platform.windowReads
        let end = harness.time.now + duration
        while harness.time.now < end {
            await harness.advance(.milliseconds(100))
            let now = harness.platform.windowReads
            if now > count { seen += Array(repeating: harness.time.now, count: now - count) }
            count = now
        }
        return seen
    }

    /// Boosting at 1.3 s: the boost-on request reads at 1.9 s, then every watch tick at a multiple of 2 s.
    @Test func everyTickLandsOnTheGrid() async {
        let harness = SignalsHarness(fullScreenVideoRule: true)
        await harness.start()
        await harness.advance(.milliseconds(1_300))                          // the launch check settled at 0.6 s
        let boostOn = harness.time.now
        harness.monitor.setBoostActive(true)
        let seen = await reads(harness, for: .milliseconds(10_800))           // until 12.1 s
        let request = boostOn + FullScreenTracker.debounce
        #expect(seen.filter { $0 == request }.count == 1)
        let ticks = seen.filter { $0 != request }
        #expect(ticks == stride(from: 2, through: 12, by: 2).map { at(.seconds($0)) }, "\(ticks)")
    }

    /// Between ticks the watch is one sleeper whose deadline is the next grid point (the instant every other user of
    /// the grid waits for too), never a deadline of its own phase.
    @Test func theWatchSleepsUntilTheNextGridPoint() async {
        let harness = SignalsHarness(fullScreenVideoRule: true)
        await harness.start()
        await harness.advance(.milliseconds(1_300))
        harness.monitor.setBoostActive(true)
        await harness.advance(.milliseconds(650))                             // the boost-on request ran at 1.9 s
        #expect(harness.time.sleeperCount == 1)
        #expect(harness.time.nextDeadline == at(.seconds(2)))
        await harness.advance(.milliseconds(1_000))                           // 2.95 s
        #expect(harness.time.nextDeadline == at(.seconds(4)))
        #expect(harness.time.nextDeadline == harness.time.nextGridPoint(every: interval))
    }

    /// Starting just after, just before, exactly on and between grid points, the first tick reads the window list at
    /// the next grid point, at most 2 s after boosting.
    @Test(arguments: [0, 1, 1_999, 700]) func theFirstTickComesWithinTwoSecondsOfBoosting(offsetMilliseconds: Int) async {
        let harness = SignalsHarness(fullScreenVideoRule: true)
        await harness.start()
        await harness.advance(.milliseconds(2_000 + offsetMilliseconds))      // the launch check settled
        let boostOn = harness.time.now
        harness.monitor.setBoostActive(true)
        let tick = MonotonicInstant.nextGridPoint(after: boostOn, every: interval)
        #expect(tick > boostOn && tick - boostOn <= interval, "boost at \(boostOn.sinceOrigin), tick \(tick)")
        await harness.advance(tick - harness.time.now - .milliseconds(1))    // the boost-on request may run first
        let before = harness.platform.windowReads
        await harness.advance(.milliseconds(1))
        #expect(harness.platform.windowReads == before + 1, "boost at \(boostOn.sinceOrigin), tick \(tick)")
    }

    /// The watch stops with the boost and starts again later on the same grid, not on the phase of the restart.
    @Test func aRestartedWatchKeepsTheGrid() async {
        let harness = SignalsHarness(fullScreenVideoRule: true)
        await harness.start()
        await harness.advance(.milliseconds(1_000))
        harness.monitor.setBoostActive(true)
        await harness.advance(.milliseconds(3_000))                           // ticks at 2 s and 4 s
        harness.monitor.setBoostActive(false)
        await harness.advance(.milliseconds(3_700))                           // 7.7 s, nothing running
        #expect(harness.time.sleeperCount == 0)
        let boostOn = harness.time.now
        harness.monitor.setBoostActive(true)
        let seen = await reads(harness, for: .milliseconds(4_400))           // until 12.1 s
        let ticks = seen.filter { $0 != boostOn + FullScreenTracker.debounce }
        #expect(ticks == [at(.seconds(8)), at(.seconds(10)), at(.seconds(12))], "\(ticks)")
    }
}
