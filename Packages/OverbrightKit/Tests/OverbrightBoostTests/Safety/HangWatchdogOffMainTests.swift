// OverbrightBoostTests/Safety/HangWatchdogOffMainTests.swift — the watchdog's entry points run off the main actor
// without trapping (ARCHITECTURE.md §7.1 "one test that invokes the entry point from a background queue", §8.1 rule 2):
// the timer handler on its utility queue, the pong on the real main queue, and every method from any thread at once.
import Dispatch
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightBoost

@Suite nonisolated struct HangWatchdogOffMainTests {
    /// Switched on from a background queue, the timer pings the real main queue and gets answers: the handler ran on
    /// the watchdog's queue and the pong on main, neither trapped.
    @Test func theTimerAndThePongRunAgainstTheRealMainQueue() async {
        let h = WatchdogHarness()
        let watchdog = h.watchdog(ping: .milliseconds(30), timeout: .seconds(5), queue: .main)
        DispatchQueue.global(qos: .utility).async { watchdog.setActive(true) }
        #expect(await waitUntil(.seconds(10)) { watchdog.pongCount >= 3 })
        let switchedOff = LockedState(false)
        DispatchQueue.global(qos: .utility).async {
            watchdog.setActive(false)
            switchedOff.withLock { $0 = true }
        }
        #expect(await waitUntil(.seconds(10)) { switchedOff.withLock { $0 } })
        #expect(!watchdog.isActive && watchdog.fireCount == 0)
    }

    /// The handler, the pong and the switch called from many threads at once (Thread Sanitizer checks the state).
    @Test func everyEntryPointIsSafeFromAnyThread() async {
        let h = WatchdogHarness()
        let watchdog = h.watchdog(ping: .milliseconds(5), timeout: .milliseconds(20))
        DispatchQueue.concurrentPerform(iterations: 64) { i in
            switch i % 4 {
            case 0: watchdog.setActive(true)
            case 1: watchdog.tick(generation: UInt64(i))
            case 2: watchdog.pong(UInt64(i))
            default: _ = watchdog.consumeFiredFlag()
            }
        }
        watchdog.setActive(true)
        #expect(await waitUntil(.seconds(10)) { watchdog.pongCount >= 3 })
        DispatchQueue.concurrentPerform(iterations: 16) { i in watchdog.setActive(i % 2 == 0) }
        watchdog.setActive(false)
        #expect(!watchdog.isActive)
    }

    /// The shipped initializer pings the main queue with the 2 s / 3 s timings.
    @Test func theShippedWatchdogPingsTheMainQueue() async {
        let h = WatchdogHarness()
        let watchdog = HangWatchdog(writer: h.writer, ledger: h.ledger, journal: h.journal)
        watchdog.setActive(true)
        #expect(await waitUntil(.seconds(10)) { watchdog.pongCount >= 1 })
        watchdog.setActive(false)
        #expect(watchdog.fireCount == 0 && h.ledger.hangEpoch == 0)
    }
}
