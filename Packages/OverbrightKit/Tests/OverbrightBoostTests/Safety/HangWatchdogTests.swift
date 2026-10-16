// OverbrightBoostTests/Safety/HangWatchdogTests.swift — the hang watchdog (ARCHITECTURE.md §4.6, §7.4, §10.7
// acceptance: restores within 3–5 s of a stall, fired from its background queue, under Thread Sanitizer:
// `make tsan FILTER=HangWatchdogTests`). The stalled "main thread" is a queue the test blocks; the off-main entry points
// against the real main queue are in `HangWatchdogOffMainTests`.
import Dispatch
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightBoost

@Suite(.serialized) nonisolated struct HangWatchdogTests {
    private let quickPing: Duration = .milliseconds(40)
    private let quickTimeout: Duration = .milliseconds(120)

    /// The acceptance case, with the shipped 2 s ping and 3 s timeout.
    @Test func restoresWithinThreeToFiveSecondsOfAStall() async throws {
        let h = WatchdogHarness()
        let watchdog = h.watchdog(ping: EngineTiming.hangPing, timeout: EngineTiming.hangTimeout)
        watchdog.setActive(true)
        defer { watchdog.setActive(false) }
        #expect(await waitUntil(.seconds(10)) { watchdog.pongCount >= 1 })
        let stall = h.stall()
        defer { stall.release() }
        #expect(await waitUntil(.seconds(15)) { watchdog.fireCount == 1 })
        let started = try #require(stall.startedAt), fired = try #require(watchdog.lastFiredAt)
        let delay = seconds(from: started, to: fired)
        #expect(delay >= 2.9 && delay <= 5.5, "fired \(delay) s after the stall began")
        #expect(h.ledger.hangEpoch == 1 && h.ledger.entries().isEmpty)
        #expect(h.codes.contains("hang.fired"))
        #expect(watchdog.consumeFiredFlag())
        #expect(!watchdog.consumeFiredFlag())
    }

    @Test func aResponsiveMainThreadNeverFires() async {
        let h = WatchdogHarness()
        let watchdog = h.watchdog(ping: quickPing, timeout: quickTimeout)
        watchdog.setActive(true)
        #expect(await waitUntil(.seconds(10)) { watchdog.pongCount >= 8 })
        watchdog.setActive(false)
        #expect(watchdog.fireCount == 0 && !watchdog.consumeFiredFlag())
        #expect(h.ledger.hangEpoch == 0 && h.ledger.entries().map(\.display) == [h.display])
        #expect(h.gamma.writeCount == 0)
    }

    @Test func firesOncePerStallAndAgainAfterTheMainThreadAnswered() async {
        let h = WatchdogHarness()
        let watchdog = h.watchdog(ping: quickPing, timeout: quickTimeout)
        watchdog.setActive(true)
        defer { watchdog.setActive(false) }
        let first = h.stall()
        #expect(await waitUntil(.seconds(10)) { watchdog.fireCount == 1 })
        try? await Task.sleep(for: .milliseconds(500))              // still stalled: no second restore
        #expect(watchdog.fireCount == 1 && h.ledger.hangEpoch == 1)
        let pongs = watchdog.pongCount
        first.release()
        #expect(await waitUntil(.seconds(10)) { watchdog.pongCount > pongs })
        h.ledger.markScaled(h.display, baseline: h.base)            // the engine re-gated and boosts again
        let second = h.stall()
        defer { second.release() }
        #expect(await waitUntil(.seconds(10)) { watchdog.fireCount == 2 })
        #expect(h.ledger.hangEpoch == 2 && h.ledger.entries().isEmpty)
        #expect(h.codes.filter { $0 == "hang.fired" }.count == 2)
    }

    @Test func offMeansNoTimerAndNoRestore() async {
        let h = WatchdogHarness()
        let watchdog = h.watchdog(ping: quickPing, timeout: quickTimeout)
        #expect(!watchdog.isActive)
        watchdog.setActive(true)
        #expect(watchdog.isActive)
        watchdog.setActive(false)
        #expect(!watchdog.isActive)
        let stall = h.stall()
        defer { stall.release() }
        try? await Task.sleep(for: .milliseconds(600))
        #expect(watchdog.fireCount == 0 && h.ledger.hangEpoch == 0)
    }

    /// A write in flight holds the ledger lock across the WindowServer call; the watchdog's restore waits for it, so
    /// the in-flight write lands first and the baseline after it (§4.6).
    @Test func aWriteInFlightLandsBeforeTheRestore() async {
        let h = WatchdogHarness()
        let watchdog = h.watchdog(ping: quickPing, timeout: quickTimeout)
        watchdog.setActive(true)
        defer { watchdog.setActive(false) }
        let writeStuck = DispatchSemaphore(value: 0), writeStarted = LockedState(false)
        let ledger = h.ledger, gamma = h.gamma, scaled = h.base.scaled(by: 1.5)
        Thread.detachNewThread {
            ledger.withLock { _ in                                    // what TableWriter.write does
                writeStarted.withLock { $0 = true }
                writeStuck.wait()
                try? gamma.write(scaled, to: 1)
            }
        }
        #expect(await waitUntil(.seconds(10)) { writeStarted.withLock { $0 } })
        let stall = h.stall()
        defer { stall.release() }
        try? await Task.sleep(for: .milliseconds(800))              // well past the timeout
        #expect(watchdog.fireCount == 0)                            // blocked behind the write's lock (the ledger
        writeStuck.signal()                                         // is not read here: the write holds its lock)
        #expect(await waitUntil(.seconds(10)) { watchdog.fireCount == 1 })
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
        #expect(await waitUntil(.seconds(10)) { watchdog.fireCount == 1 })
        #expect(h.gamma.table(of: 1) == h.base && h.gamma.table(of: 2) == h.base)
    }
}
