// OverbrightBoostTests/Safety/HangWatchdogTests.swift — the hang watchdog (ARCHITECTURE.md §4.6, §7.4, §10.7
// acceptance: restores within 3–5 s of a stall, fired from its background queue, under Thread Sanitizer:
// `make tsan FILTER=HangWatchdogTests`). The stalled "main thread" is a queue the test blocks; the off-main entry points
// against the real main queue are in `HangWatchdogOffMainTests`.
//
// The timing rules (the 3–5 s window, once per stall, never while answered, pings on the shared 2 s grid, D29) are
// checked on explicit uptimes through the watchdog's pure tick (`HangWatchdog.gridStep`, `.step`, `.answer`), so no result
// depends on how a loaded machine schedules a timer (§9.1, WP14). The tests with the real timer check what does not depend on it: a stall is restored from the watchdog's
// queue, never sooner than `hangTimeout` after the unanswered ping was sent, and a write in flight lands first. They
// wait for the timer with a scheduling margin only a real failure reaches, and for queues through blocks queued on them.
import Dispatch
import Foundation
import OverbrightCore
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@Suite(.serialized, .timeLimit(.minutes(5))) nonisolated struct HangWatchdogTests {
    private let quickPing: Duration = .milliseconds(40)
    private let quickTimeout: Duration = .milliseconds(120)
    /// How long the watchdog's utility queue may take to run a timer that is due (a margin, not a timing).
    private static let timerMargin: Duration = .seconds(120)

    private static func ns(_ duration: Duration) -> UInt64 { HangWatchdog.nanoseconds(duration) }
    private static let second: UInt64 = 1_000_000_000

    // MARK: The rules, on explicit times

    /// What a simulated run saw, in uptimes (ns).
    private struct Run {
        var fires: [UInt64] = []
        var pings: [UInt64] = []
    }

    /// The watchdog's tick and the pinged queue's answers on explicit uptimes (ns). The timer ticks when `gridStep`
    /// says, on the grid of a time source that reads `phase` at uptime 0 (only its place in a period matters, D29);
    /// each ping is answered `latency` after it was sent, unless the queue was stalled when it was sent (a stall is a
    /// block queued ahead of the pong): then `latency` after the stall ends.
    private func run(stalls: [Range<UInt64>], latency: UInt64 = 1_000_000, until end: UInt64, phase: UInt64 = 0,
                     ping: Duration = EngineTiming.hangPing, timeout: Duration = EngineTiming.hangTimeout) -> Run {
        var s = HangWatchdog.State()
        var now: UInt64 = 0
        var answer: (id: UInt64, at: UInt64)?
        var seen = Run()
        while now <= end {
            if let pending = answer, pending.at <= now {
                _ = HangWatchdog.answer(&s, ping: pending.id)
                answer = nil
            }
            let toGrid = HangWatchdog.nextPingDelay(sinceOrigin: .nanoseconds(Int64(now + phase)), interval: ping)
            let (step, next) = HangWatchdog.gridStep(&s, at: now, toGrid: toGrid, interval: Self.ns(ping),
                                                     timeout: Self.ns(timeout))
            switch step {
            case .ping(let id):
                let blocked = stalls.first { $0.contains(now) }
                answer = (id, (blocked?.upperBound ?? now) + latency)
                seen.pings.append(now)
            case .fire:
                seen.fires.append(now)
            case .idle:
                break
            }
            guard next > 0 else {
                Issue.record("the timer would tick again at once at \(now)")
                break
            }
            now += next
        }
        return seen
    }

    /// The uptimes of the restores of `run`.
    private func restores(stalls: [Range<UInt64>], latency: UInt64 = 1_000_000, until end: UInt64,
                          phase: UInt64 = 0) -> [UInt64] {
        run(stalls: stalls, latency: latency, until: end, phase: phase).fires
    }

    /// Grid phases: on the grid at uptime 0, just after and just before a grid point, and two arbitrary ones.
    private static let phases: [UInt64] = [0, 1, 1_999_999_999, 370_000_000, 123_456_789_123]

    /// A stall that starts anywhere in a ping period is restored at least `hangTimeout` and at most `hangPing +
    /// hangTimeout` after it began, once, at every grid phase; both ends of the 3–5 s window are reached.
    @Test(arguments: phases) func aStallIsCaughtThreeToFiveSecondsAfterItBegins(phase: UInt64) {
        let latency: UInt64 = 1_000_000
        var delays: [UInt64] = []
        for start in stride(from: 10 * Self.second, through: 12 * Self.second, by: 10_000_000) {
            let fires = restores(stalls: [start..<(start + 30 * Self.second)], latency: latency,
                                 until: start + 25 * Self.second, phase: phase)
            guard fires.count == 1, let fired = fires.first, fired >= start else {
                Issue.record("stall at \(start): restores \(fires)")
                continue
            }
            delays.append(fired - start)
        }
        let low = Self.ns(EngineTiming.hangTimeout), high = Self.ns(EngineTiming.hangPing + EngineTiming.hangTimeout)
        #expect(delays.allSatisfy { $0 >= low - latency && $0 <= high }, "\(delays.min() ?? 0)…\(delays.max() ?? 0)")
        #expect((delays.min() ?? 0) <= low + 20_000_000 && (delays.max() ?? 0) >= high - 20_000_000)
    }

    /// Pings answered within the timeout never restore, however long the watchdog runs; a slow answer is late only
    /// once it waited the whole timeout.
    @Test(arguments: phases) func anAnsweredPingNeverFires(phase: UInt64) {
        #expect(restores(stalls: [], until: 600 * Self.second, phase: phase) == [])
        let timeout = Self.ns(EngineTiming.hangTimeout)
        #expect(restores(stalls: [], latency: timeout - 1_000_000, until: 600 * Self.second, phase: phase) == [])
        #expect(restores(stalls: [], latency: timeout + 1_000_000, until: timeout + Self.second, phase: phase)
                == [timeout])
    }

    /// One restore per stall however long it lasts; after the queue answered, the next stall restores again.
    @Test(arguments: phases) func firesOncePerStallAndAgainAfterTheMainThreadAnswered(phase: UInt64) {
        let first = (10 * Self.second)..<(40 * Self.second), second = (50 * Self.second)..<(60 * Self.second)
        let fires = restores(stalls: [first, second], until: 70 * Self.second, phase: phase)
        #expect(fires.count == 2, "\(fires)")
        #expect(fires.first.map(first.contains) == true && fires.last.map(second.contains) == true)
    }

    // MARK: The shared grid (D29)

    /// For 10 000 seeded readings of the time source (up to 30 days since its origin) the wait to the next ping is in
    /// (0, `hangPing`] and ends on a multiple of `hangPing` since the origin.
    @Test func thePingDelayIsWithinOneIntervalForAnyOrigin() {
        var generator = SeededGenerator(seed: 0x7069_6e67)
        let interval = Self.ns(EngineTiming.hangPing)
        for _ in 0..<10_000 {
            let sinceOrigin = UInt64.random(in: 0...(30 * 86_400 * Self.second), using: &generator)
            let delay = HangWatchdog.nextPingDelay(sinceOrigin: .nanoseconds(Int64(sinceOrigin)),
                                                   interval: EngineTiming.hangPing)
            #expect(delay > 0 && delay <= interval, "\(sinceOrigin) → \(delay)")
            #expect((sinceOrigin + delay) % interval == 0, "\(sinceOrigin) → \(delay)")
        }
        #expect(HangWatchdog.nextPingDelay(sinceOrigin: .seconds(4), interval: EngineTiming.hangPing) == interval)
        #expect(HangWatchdog.nextPingDelay(sinceOrigin: .seconds(4) + .nanoseconds(1), interval: EngineTiming.hangPing)
                == interval - 1)
        // A fraction of a nanosecond before a grid point still waits a whole nanosecond, never zero.
        let almost = Duration(secondsComponent: 3, attosecondsComponent: 999_999_999_999_999_999)
        #expect(HangWatchdog.nextPingDelay(sinceOrigin: almost, interval: EngineTiming.hangPing) == 1)
    }

    /// The first ping goes out when the watchdog starts; every later one lands on a grid point, `hangPing` apart, at
    /// any phase, so it shares the wake-up of the other 2 s activities on the same time source. The second one comes
    /// at the first grid point after the first answer (1 ms here): within `hangPing` of it.
    @Test(arguments: phases) func pingsAfterTheFirstLandOnTheGrid(phase: UInt64) {
        let interval = Self.ns(EngineTiming.hangPing), latency: UInt64 = 1_000_000
        let pings = run(stalls: [], latency: latency, until: 120 * Self.second, phase: phase).pings
        #expect(pings.first == 0 && pings.count >= 60)
        #expect(pings.dropFirst().allSatisfy { ($0 + phase) % interval == 0 }, "\(pings.prefix(4))")
        #expect(zip(pings.dropFirst(), pings.dropFirst(2)).allSatisfy { $1 - $0 == interval })
        #expect(pings.count >= 2 && pings[1] >= latency && pings[1] - latency <= interval, "\(pings.prefix(2))")
    }

    /// The first ping goes out 1 ms before a grid point and is answered 5 ms later, after that point; the main thread
    /// then stalls. The next ping follows within `hangPing` of the answer, so the stall is still caught within 5 s.
    /// (Rescheduling only the pings onto the grid would leave the late answer to the timeout deadline: the next ping
    /// would go out 3 s after the first, and this stall would take almost 6 s to catch.)
    @Test func anAnswerAfterAShortFirstWaitStillCatchesTheNextStallWithinFiveSeconds() {
        let latency: UInt64 = 5_000_000, stallStart: UInt64 = 6_000_000
        let seen = run(stalls: [stallStart..<(60 * Self.second)], latency: latency, until: 30 * Self.second,
                       phase: Self.ns(EngineTiming.hangPing) - 1_000_000)
        #expect(seen.fires.count == 1, "\(seen.fires)")
        let caught = (seen.fires.first ?? .max) - stallStart
        #expect(caught >= Self.ns(EngineTiming.hangTimeout))
        #expect(caught <= Self.ns(EngineTiming.hangPing + EngineTiming.hangTimeout), "\(caught)")
        #expect(seen.pings.count >= 2 && seen.pings[1] - latency <= Self.ns(EngineTiming.hangPing))
    }

    /// Answered pings never wake the timer between grid points: per 2 s period one tick, the ping's.
    @Test func aResponsiveQueueCostsOneTickPerPeriod() {
        var s = HangWatchdog.State()
        let interval = Self.ns(EngineTiming.hangPing), timeout = Self.ns(EngineTiming.hangTimeout)
        var now: UInt64 = 0, ticks = 0
        let phase: UInt64 = 370_000_000
        while now <= 600 * Self.second {
            ticks += 1
            let toGrid = HangWatchdog.nextPingDelay(sinceOrigin: .nanoseconds(Int64(now + phase)),
                                                   interval: EngineTiming.hangPing)
            let (step, next) = HangWatchdog.gridStep(&s, at: now, toGrid: toGrid, interval: interval, timeout: timeout)
            if case .ping(let id) = step { _ = HangWatchdog.answer(&s, ping: id) }    // answered before the next tick
            now += next
        }
        #expect(ticks == 301, "\(ticks)")                                     // uptime 0, then 300 grid points
    }

    // MARK: The real timer

    /// Waits until the timer sent a ping, then until its pong ran on the harness's queue (a block queued there after
    /// the pong runs after it).
    private func pingAnswered(_ watchdog: HangWatchdog, _ h: WatchdogHarness) async -> Bool {
        guard await waitUntil(Self.timerMargin, { watchdog.pingCount >= 1 }) else { return false }
        await watchdog.drainQueue()                                       // the tick that pinged enqueued the pong
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            h.pinged.async { continuation.resume() }
        }
        return watchdog.pongCount >= 1
    }

    /// The acceptance case with the shipped 2 s ping and 3 s timeout: a stall is restored from the watchdog's queue,
    /// never sooner than the timeout after the unanswered ping (the 3–5 s window itself is checked on explicit times
    /// above, `aStallIsCaughtThreeToFiveSecondsAfterItBegins`).
    @Test func restoresWithinThreeToFiveSecondsOfAStall() async throws {
        let h = WatchdogHarness()
        let watchdog = h.watchdog(ping: EngineTiming.hangPing, timeout: EngineTiming.hangTimeout)
        watchdog.setActive(true)
        defer { watchdog.setActive(false) }
        #expect(await pingAnswered(watchdog, h))
        let stall = h.stall()
        defer { stall.release() }
        #expect(await waitUntil(Self.timerMargin) { watchdog.fireCount >= 1 })
        let sent = try #require(watchdog.lastTimedOutPingSentAt), fired = try #require(watchdog.lastFiredAt)
        #expect(seconds(from: sent, to: fired) >= EngineTiming.hangTimeout.timeInterval)
        #expect(h.ledger.hangEpoch >= 1 && h.ledger.entries().isEmpty)
        #expect(h.codes.contains("hang.fired"))
        #expect(watchdog.consumeFiredFlag())
        #expect(!watchdog.consumeFiredFlag())
    }

    /// The real timer waits for the writer's time-source grid (D29): with that clock 10 ms before a grid point, the
    /// tick that pinged schedules the next tick 10 ms later, not a whole `hangPing` (the clock stands still, so every
    /// tick until the switch-off asks for the same 10 ms).
    @Test func theTimerSchedulesTheNextPingOnTheWritersGrid() async {
        let h = WatchdogHarness()
        await h.time.advance(by: .milliseconds(1_990))
        let watchdog = h.watchdog(ping: EngineTiming.hangPing, timeout: .seconds(3_600))
        watchdog.setActive(true)
        #expect(await waitUntil(Self.timerMargin) { watchdog.pingCount >= 1 })
        watchdog.setActive(false)
        await watchdog.drainQueue()
        #expect(watchdog.lastScheduledDelay == 10_000_000)
        #expect(watchdog.fireCount == 0)
    }

    /// A responsive queue is pinged again and again and every answer is heard (the timeout is longer than any run, so
    /// a slow answer never fires here); nothing is written.
    @Test func aResponsiveMainThreadNeverFires() async {
        let h = WatchdogHarness()
        let watchdog = h.watchdog(ping: quickPing, timeout: .seconds(3_600))
        watchdog.setActive(true)
        #expect(await waitUntil(Self.timerMargin) { watchdog.pongCount >= 8 })
        watchdog.setActive(false)
        await watchdog.drainQueue()
        #expect(watchdog.fireCount == 0 && !watchdog.consumeFiredFlag())
        #expect(h.ledger.hangEpoch == 0 && h.ledger.entries().map(\.display) == [h.display])
        #expect(h.gamma.writeCount == 0)
    }

    /// Switched off, the watchdog holds no timer, and no tick of any generation pings or restores, even with the
    /// pinged queue stalled.
    @Test func offMeansNoTimerAndNoRestore() async {
        let h = WatchdogHarness()
        let watchdog = h.watchdog(ping: quickPing, timeout: quickTimeout)
        #expect(!watchdog.isActive)
        watchdog.setActive(true)
        #expect(watchdog.isActive)
        watchdog.setActive(false)
        #expect(!watchdog.isActive)
        await watchdog.drainQueue()
        let stall = h.stall()
        defer { stall.release() }
        let pings = watchdog.pingCount
        for generation in 0...8 { watchdog.tick(generation: UInt64(generation)) }
        #expect(watchdog.pingCount == pings && watchdog.fireCount == 0 && h.ledger.hangEpoch == 0)
    }

    /// A write in flight holds the ledger lock across the WindowServer call; the watchdog's restore waits for it, so
    /// the in-flight write lands first and the baseline after it (§4.6). The watchdog starts with the write already
    /// in flight and the queue stalled, so its one restore is the one that waits.
    @Test func aWriteInFlightLandsBeforeTheRestore() async {
        let h = WatchdogHarness()
        let watchdog = h.watchdog(ping: quickPing, timeout: quickTimeout)
        let writeStuck = DispatchSemaphore(value: 0), writeStarted = LockedState(false)
        let ledger = h.ledger, gamma = h.gamma, scaled = h.base.scaled(by: 1.5)
        Thread.detachNewThread {
            ledger.withLock { _ in                                    // what TableWriter.write does
                writeStarted.withLock { $0 = true }
                writeStuck.wait()
                try? gamma.write(scaled, to: 1)
            }
        }
        #expect(await waitUntil(Self.timerMargin) { writeStarted.withLock { $0 } })
        let stall = h.stall()
        defer { stall.release() }
        watchdog.setActive(true)
        defer { watchdog.setActive(false) }
        // The ping timed out and the restore started: it waits for the write's lock (the ledger is not read here).
        #expect(await waitUntil(Self.timerMargin) { watchdog.lastTimedOutPingSentAt != nil })
        #expect(watchdog.fireCount == 0)
        writeStuck.signal()
        #expect(await waitUntil(Self.timerMargin) { watchdog.fireCount == 1 })
        #expect(h.ledger.hangEpoch == 1)
        #expect(h.gamma.writes.first?.table == scaled)
    }

    // MARK: With WP4's writer body

    @Test(.enabled(if: TableWriterProbe.writesBaselines, "needs WP4's TableWriter.writeBaselines"))
    func theBaselinesReachTheDisplays() async {
        let h = WatchdogHarness()
        h.gamma.addDisplay(2, base: h.base, table: h.base.scaled(by: 0.5))       // a dimmed display
        h.ledger.markScaled(DisplayRef(key: DisplayFixture.Keys.mpg322ux, id: 2), baseline: h.base)
        let watchdog = h.watchdog(ping: quickPing, timeout: quickTimeout)
        watchdog.setActive(true)
        defer { watchdog.setActive(false) }
        let stall = h.stall()
        defer { stall.release() }
        #expect(await waitUntil(Self.timerMargin) { watchdog.fireCount >= 1 })
        #expect(h.gamma.table(of: 1) == h.base && h.gamma.table(of: 2) == h.base)
    }
}
