// OverbrightBoostTests/Safety/SignalStopTests.swift — TERM/INT/HUP (ARCHITECTURE.md §7.4, D7): ledger baselines first,
// on the signal queue; then the main-actor stop, waited for at most 1 s; then exit(0). `exit` is replaced, so the test
// process survives; one test delivers a real SIGHUP to the process through the installed dispatch source.
import Darwin
import Dispatch
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightBoost

@Suite(.serialized) nonisolated struct SignalStopTests {
    /// What the handlers did, in order, from whichever thread did it.
    nonisolated final class Trace: Sendable {
        private let steps = LockedState<[String]>([])
        private let exitThread = LockedState<Bool?>(nil)
        var all: [String] { steps.withLock { $0 } }
        /// Whether `exit` was called on the main thread (nil: not called).
        var exitedOnMainThread: Bool? { exitThread.withLock { $0 } }
        func add(_ step: String) { steps.withLock { $0.append(step) } }
        func exited(_ code: Int32) {
            exitThread.withLock { $0 = Thread.isMainThread }
            add("exit(\(code))")
        }
    }

    private func makeHandlers(_ h: WatchdogHarness, trace: Trace, timeout: Duration = EngineTiming.signalStopTimeout,
                          stop: @escaping @MainActor @Sendable () async -> Void) -> SignalHandlers {
        SignalHandlers(writer: h.writer, stop: stop, timeout: timeout) { trace.exited($0) }
    }

    /// Runs `handle` on a background queue (as the signal queue would) and waits for it to return.
    private func deliver(_ number: Int32, to handlers: SignalHandlers) async {
        let returned = LockedState(false)
        DispatchQueue.global(qos: .userInitiated).async {
            handlers.handle(number)
            returned.withLock { $0 = true }
        }
        _ = await waitUntil(.seconds(10)) { returned.withLock { $0 } }
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

    @Test func aHungMainActorDelaysTheExitByOneSecondOnly() async {
        let h = WatchdogHarness()
        let trace = Trace()
        let handlers = makeHandlers(h, trace: trace) {
            try? await Task.sleep(for: .seconds(20))                 // a stop that does not finish in time
            trace.add("late stop")
        }
        let clock = ContinuousClock(), start = clock.now
        await deliver(SIGTERM, to: handlers)
        let waited = start.duration(to: clock.now)
        #expect(trace.all == ["exit(0)"])
        #expect(waited >= .milliseconds(950) && waited < .seconds(5), "exited after \(waited)")
        #expect(h.ledger.hangEpoch == 1 && h.ledger.entries().isEmpty)
        #expect(h.codes.contains("signal.stopTimedOut"))
    }

    @Test func onlyTheFirstSignalIsHandled() async {
        let h = WatchdogHarness()
        let trace = Trace()
        let handlers = makeHandlers(h, trace: trace, timeout: .milliseconds(200)) { trace.add("stop") }
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
        let handlers = makeHandlers(h, trace: trace, timeout: .milliseconds(500)) { trace.add("stop") }
        handlers.install()
        handlers.install()                                           // once only
        #expect(handlers.sourceCount == SignalHandlers.handledSignals.count)
        defer { handlers.uninstall() }
        kill(getpid(), SIGHUP)
        #expect(await waitUntil(.seconds(10)) { trace.all.contains("exit(0)") })
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
