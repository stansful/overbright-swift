// OverbrightBoostTests/Safety/SignalStopTests.swift — TERM/INT/HUP (ARCHITECTURE.md §7.4, D7): ledger baselines first,
// on the signal queue; then the main-actor stop, waited for at most 1 s; then exit(0). `exit` is replaced, so the test
// process survives; one test delivers a real SIGHUP to the process through the installed dispatch source.
//
// Nothing here depends on how soon a loaded main actor runs the stop (§9.1, WP14 C-BOOST-14): tests that are not about
// the timeout wait for the stop without a bound, the timeout's own test is handed a wait that times out at once, and
// the shipped bounded wait is checked on a semaphore of its own (it never returns early). Each test waits for the
// handler to return, or for `exit`, through a continuation the handler resumes, never by polling a clock.
import Darwin
import Dispatch
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightBoost

@Suite(.serialized, .timeLimit(.minutes(2))) nonisolated struct SignalStopTests {
    /// What the handlers did, in order, from whichever thread did it; `exited()` returns once `exit` was called.
    nonisolated final class Trace: Sendable {
        private let steps = LockedState<[String]>([])
        private let exitThread = LockedState<Bool?>(nil)
        private let exitWaiters = LockedState<[CheckedContinuation<Void, Never>]>([])
        var all: [String] { steps.withLock { $0 } }
        /// Whether `exit` was called on the main thread (nil: not called).
        var exitedOnMainThread: Bool? { exitThread.withLock { $0 } }
        func add(_ step: String) { steps.withLock { $0.append(step) } }
        func exited(_ code: Int32) {
            exitThread.withLock { $0 = Thread.isMainThread }
            add("exit(\(code))")
            for waiter in exitWaiters.withLock({ waiters in defer { waiters = [] }; return waiters }) { waiter.resume() }
        }
        /// Returns once `exit` was called (at once if it was).
        func exited() async {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                let called = exitWaiters.withLock { waiters in
                    if exitThread.withLock({ $0 != nil }) { return true }
                    waiters.append(continuation)
                    return false
                }
                if called { continuation.resume() }
            }
        }
    }

    /// The wait for a stop that returns at once: until it ran, however long a loaded main actor takes to get to it.
    private static let untilTheStopRan: SignalHandlers.StopWait = { done, _ in
        done.wait()
        return true
    }

    private func makeHandlers(_ h: WatchdogHarness, trace: Trace, wait: @escaping SignalHandlers.StopWait = untilTheStopRan,
                              stop: @escaping @MainActor @Sendable () async -> Void) -> SignalHandlers {
        SignalHandlers(writer: h.writer, stop: stop, timeout: EngineTiming.signalStopTimeout, wait: wait,
                       terminate: { trace.exited($0) })
    }

    /// Runs `handle` on a background queue (as the signal queue would) and returns once it returned.
    private func deliver(_ number: Int32, to handlers: SignalHandlers) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                handlers.handle(number)
                continuation.resume()
            }
        }
    }

    @Test(arguments: [SIGTERM, SIGINT, SIGHUP])
    func baselinesThenTheStopThenExit(_ number: Int32) async {
        let h = WatchdogHarness()
        let trace = Trace()
        let ledger = h.ledger
        let handlers = makeHandlers(h, trace: trace) {
            // By the time the main actor is asked, the ledger was restored and the epoch bumped.
            trace.add("stop(epoch \(ledger.hangEpoch), entries \(ledger.entries().count))")
        }
        await deliver(number, to: handlers)
        #expect(trace.all == ["stop(epoch 1, entries 0)", "exit(0)"])
        #expect(trace.exitedOnMainThread == false)
        #expect(h.codes.contains("signal.received") && !h.codes.contains("signal.stopTimedOut"))
    }

    /// A main actor that does not finish the stop in time: the handler waits the 1 s `signalStopTimeout` (here a wait
    /// that reports it passed), journals it and exits without the stop.
    @Test func aHungMainActorDelaysTheExitByOneSecondOnly() async {
        let h = WatchdogHarness()
        let trace = Trace()
        let bounds = LockedState<[Duration]>([])
        let handlers = makeHandlers(h, trace: trace, wait: { _, timeout in
            bounds.withLock { $0.append(timeout) }
            return false                                             // the timeout passed, the stop did not finish
        }, stop: {
            await trace.exited()                                     // a stop that finishes only after the exit
            trace.add("late stop")
        })
        await deliver(SIGTERM, to: handlers)
        #expect(bounds.withLock { $0 } == [EngineTiming.signalStopTimeout])
        #expect(trace.all.first == "exit(0)")
        #expect(h.ledger.hangEpoch == 1 && h.ledger.entries().isEmpty)
        #expect(h.codes.contains("signal.stopTimedOut"))
    }

    /// The shipped wait gives up only after its bound (a semaphore wait never returns early) and returns at once for a
    /// stop that already finished.
    @Test func theShippedWaitIsBoundedByItsTimeout() {
        let never = DispatchSemaphore(value: 0)
        let clock = ContinuousClock(), start = clock.now
        #expect(!SignalHandlers.waitAtMost(never, .milliseconds(50)))
        #expect(start.duration(to: clock.now) >= .milliseconds(50))
        let done = DispatchSemaphore(value: 0)
        done.signal()
        #expect(SignalHandlers.waitAtMost(done, .seconds(3_600)))
    }

    @Test func onlyTheFirstSignalIsHandled() async {
        let h = WatchdogHarness()
        let trace = Trace()
        let handlers = makeHandlers(h, trace: trace) { trace.add("stop") }
        await deliver(SIGINT, to: handlers)
        await deliver(SIGTERM, to: handlers)
        #expect(trace.all == ["stop", "exit(0)"])
        #expect(h.ledger.hangEpoch == 1)
    }

    /// A real SIGHUP sent to this process reaches the handler through the dispatch source on the signal queue (its
    /// default action, which would end the test run, is ignored while installed).
    @Test func aRealSignalReachesTheInstalledHandler() async {
        let h = WatchdogHarness()
        let trace = Trace()
        let handlers = makeHandlers(h, trace: trace) { trace.add("stop") }
        handlers.install()
        handlers.install()                                           // once only
        #expect(handlers.sourceCount == SignalHandlers.handledSignals.count)
        defer { handlers.uninstall() }
        kill(getpid(), SIGHUP)
        await trace.exited()
        #expect(trace.all == ["stop", "exit(0)"])
        #expect(trace.exitedOnMainThread == false)
        #expect(h.ledger.hangEpoch == 1 && h.ledger.entries().isEmpty)
    }

    @Test(.enabled(if: TableWriterProbe.writesBaselines, "needs WP4's TableWriter.writeBaselines"))
    func theBaselinesReachTheDisplaysBeforeTheStop() async {
        let h = WatchdogHarness()
        let trace = Trace()
        let gamma = h.gamma, base = h.base
        let handlers = makeHandlers(h, trace: trace) {
            trace.add(gamma.table(of: 1) == base ? "stop at base" : "stop scaled")
        }
        await deliver(SIGTERM, to: handlers)
        #expect(trace.all == ["stop at base", "exit(0)"])
    }
}
