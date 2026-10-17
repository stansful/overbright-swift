// OverbrightBoostTests/Safety/SharedGridTests.swift — the drift checks and the hang watchdog's pings wait for the same
// points of the shared 2 s grid (ARCHITECTURE.md D29). The drift loop sleeps `DisplayController.gridDelay` (E4), the
// watchdog waits `HangWatchdog.nextPingDelay` (T2), and Signals' watch and the OLED input poll wait for
// `TimeSource.nextGridPoint` (T3, `WatchGridTests`); all three must name one point, because a grid that only some of
// the 2 s activities follow costs more wake-ups than none (D29: a relative timer never locks onto the grid).
import Foundation
import OverbrightCore
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct SharedGridTests {
    private static let period = EngineTiming.hangPing

    /// The drift check (D9) and the ping (D7) have one period, 2 s, the period of Signals' watch.
    @Test func theDriftCheckAndThePingShareOnePeriod() {
        #expect(EngineTiming.watchdogInterval == EngineTiming.hangPing)
        #expect(EngineTiming.hangPing == .seconds(2))
    }

    /// For 10 000 seeded readings up to 30 days from the origin, whole nanoseconds or not, the drift loop's sleep and
    /// the watchdog's wait to its next ping are the same whole number of nanoseconds, in (0, 2 s], and end on
    /// `nextGridPoint` (the drift sleep at most a fraction of a nanosecond after it, never before).
    @Test func theDriftSleepAndTheNextPingEndOnTheSamePoint() {
        var generator = SeededGenerator(seed: 0x6772_6964)
        for index in 0..<10_000 {
            let whole = Int64.random(in: 0...(30 * 86_400 * 1_000_000_000), using: &generator)
            let fraction = index.isMultiple(of: 2) ? Int64.random(in: 1..<1_000_000_000, using: &generator) : 0
            let floored = MonotonicInstant(sinceOrigin: .nanoseconds(whole))
            let now = MonotonicInstant(sinceOrigin: .nanoseconds(whole)
                                       + Duration(secondsComponent: 0, attosecondsComponent: fraction))
            let drift = DisplayController.gridDelay(from: now, every: EngineTiming.watchdogInterval)
            let ping = HangWatchdog.nextPingDelay(sinceOrigin: now.sinceOrigin, interval: EngineTiming.hangPing)
            let point = MonotonicInstant.nextGridPoint(after: now, every: Self.period)
            #expect(drift > .zero && drift <= Self.period, "\(now.sinceOrigin) → \(drift)")
            #expect(HangWatchdog.nanosecondsRoundedUp(drift) == ping, "\(now.sinceOrigin): \(drift) vs \(ping) ns")
            #expect(floored + drift == point, "\(now.sinceOrigin) → \(drift), grid point \(point.sinceOrigin)")
        }
    }

    /// In the engine, every drift read of a steady boosted display falls on a point where the engine's own hang
    /// watchdog sends a ping (from there its next ping is a whole period away), and the watchdog reads the clock the
    /// drift loop sleeps on.
    @Test func driftReadsInTheEngineFallOnPingPoints() async throws {
        var counting: CountingGammaPort?
        let h = EngineHarness(wrapGamma: { gamma, time in
            let port = CountingGammaPort(gamma, time: time)
            counting = port
            return port
        })
        let port = try #require(counting)
        let watchdogClock = ObjectIdentifier(h.engine.writer.time as AnyObject)
        #expect(watchdogClock == ObjectIdentifier(h.time))
        await h.start()
        #expect(await h.boost())
        await h.advance(.milliseconds(1_370))                             // off the grid
        await h.advance(.seconds(3))                                      // any recovery burst is over
        port.resetCounts()
        await h.advance(.seconds(20), step: .milliseconds(100))
        let reads = port.reads
        let interval = HangWatchdog.nanoseconds(Self.period)
        #expect(reads.count == 10, "\(reads.count) drift reads in 20 s")
        #expect(reads.allSatisfy {
            HangWatchdog.nextPingDelay(sinceOrigin: $0.time.sinceOrigin, interval: Self.period) == interval
        }, "\(reads.map(\.time.sinceOrigin).prefix(6))")
        #expect(h.phase() == .boosted)
    }
}
