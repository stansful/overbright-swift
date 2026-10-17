// OverbrightBoostTests/Safety/HangWatchdogOffMainTests.swift — the watchdog's entry points run off the main actor
// without trapping (ARCHITECTURE.md §7.1 "one test that invokes the entry point from a background queue", §8.1 rule 2):
// the timer handler on its utility queue, the pong on the real main queue, and every method from any thread at once.
//
// No result depends on how soon a loaded main queue answers (§9.1, WP14 C-BOOST-14). A test waits for the timer to send
// a ping (the watchdog's own utility queue, with a scheduling margin only a real failure reaches), then for the queue
// that runs the timer handler (so the ping's pong is enqueued), then for the pinged queue itself: a block queued there
// after the pong runs after it (a serial queue is first in, first out), so the pong has run when it returns. The
// timeouts are longer than any run, so a slow answer never makes a watchdog fire where a test does not expect it.
import Dispatch
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightBoost

@Suite(.timeLimit(.minutes(5))) nonisolated struct HangWatchdogOffMainTests {
    /// How long the watchdog's own utility queue may take to run a timer that is due now (a margin, not a timing).
    private static let timerMargin: Duration = .seconds(120)

    /// Returns once every block queued on `queue` before the call has run.
    private func drain(_ queue: DispatchQueue) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async { continuation.resume() }
        }
    }

    /// Waits until the timer sent a ping, then until its pong ran on `pinged`.
    private func pingAnswered(_ watchdog: HangWatchdog, pinged: DispatchQueue) async -> Bool {
        guard await waitUntil(Self.timerMargin, { watchdog.pingCount >= 1 }) else { return false }
        await watchdog.drainQueue()                                       // the tick that pinged enqueued the pong
        await drain(pinged)                                               // and the pong ran
        return watchdog.pongCount >= 1
    }

    /// Switched on from a background queue, the timer pings the real main queue and gets an answer: the handler ran on
    /// the watchdog's queue and the pong on main, neither trapped.
    @Test func theTimerAndThePongRunAgainstTheRealMainQueue() async {
        let h = WatchdogHarness()
        let watchdog = h.watchdog(ping: .milliseconds(30), timeout: .seconds(3_600), queue: .main)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .utility).async {
                watchdog.setActive(true)
                continuation.resume()
            }
        }
        #expect(await pingAnswered(watchdog, pinged: .main))
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .utility).async {
                watchdog.setActive(false)
                continuation.resume()
            }
        }
        await watchdog.drainQueue()
        #expect(!watchdog.isActive && watchdog.fireCount == 0)
    }

    /// The handler, the pong and the switch called from many threads at once (Thread Sanitizer checks the state); the
    /// timer still pings and hears the answer afterwards.
    @Test func everyEntryPointIsSafeFromAnyThread() async {
        let h = WatchdogHarness()
        let watchdog = h.watchdog(ping: .milliseconds(5), timeout: .seconds(3_600))
        DispatchQueue.concurrentPerform(iterations: 64) { i in
            switch i % 4 {
            case 0: watchdog.setActive(true)
            case 1: watchdog.tick(generation: UInt64(i))
            case 2: watchdog.pong(UInt64(i))
            default: _ = watchdog.consumeFiredFlag()
            }
        }
        watchdog.setActive(false)
        let pongs = watchdog.pongCount, pings = watchdog.pingCount
        watchdog.setActive(true)
        #expect(await waitUntil(Self.timerMargin) { watchdog.pingCount > pings })
        await watchdog.drainQueue()
        await drain(h.pinged)
        #expect(watchdog.pongCount > pongs)
        DispatchQueue.concurrentPerform(iterations: 16) { i in watchdog.setActive(i % 2 == 0) }
        watchdog.setActive(false)
        #expect(!watchdog.isActive)
    }

    /// The shipped initializer pings the real main queue with the 2 s / 3 s timings. A loaded main queue may take more
    /// than 3 s to answer, so the watchdog may fire meanwhile: once switched off and drained, every restore bumped the
    /// epoch exactly once.
    @Test func theShippedWatchdogPingsTheMainQueue() async {
        let h = WatchdogHarness()
        let watchdog = HangWatchdog(writer: h.writer, ledger: h.ledger, journal: h.journal)
        watchdog.setActive(true)
        #expect(await pingAnswered(watchdog, pinged: .main))
        watchdog.setActive(false)
        await watchdog.drainQueue()                                       // no restore is left half done
        #expect(h.ledger.hangEpoch == UInt64(watchdog.fireCount))
    }
}
