// OverbrightAppShellTests/QuitTests.swift — the quit of ARCHITECTURE.md §7.4 as built (`QuitFlow`): a user quit is
// cancelled once, waits for the launch work, stops the services (Boost first, the ramp included) and terminates again;
// a quit Apple Event terminates at once (no "User canceled" for scripts, the Dock or a logout); before any launch work
// nothing is stopped. Over the real engine and the simulated ports, the stop leaves every table at its base and no
// trigger open.
import AppKit
import CoreServices
import Foundation
import OverbrightBoost
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct QuitTests {
    private final class Record {
        var stops = 0
        var terminations = 0
    }

    private func launchedGate() async -> LaunchGate {
        let gate = LaunchGate()
        gate.launch {}
        _ = await eventually { gate.phase == .launched }
        return gate
    }

    @Test func aUserQuitIsCancelledOnceStopsThenTerminates() async {
        let record = Record()
        let flow = QuitFlow(gate: await launchedGate(), stop: { record.stops += 1 }, terminate: { record.terminations += 1 })
        #expect(flow.reply(isQuitEvent: false) == .terminateCancel)
        #expect(await eventually { record.terminations == 1 })
        #expect(record.stops == 1 && flow.state == .stopped)
        #expect(flow.reply(isQuitEvent: false) == .terminateNow)            // the second terminate goes through
        #expect(record.stops == 1)
    }

    @Test func aQuitAppleEventTerminatesAtOnce() async {
        let record = Record()
        let flow = QuitFlow(gate: await launchedGate(), stop: { record.stops += 1 }, terminate: { record.terminations += 1 })
        #expect(flow.reply(isQuitEvent: true) == .terminateNow)
        #expect(record.stops == 0 && record.terminations == 0 && flow.state == .running)
        let quit = NSAppleEventDescriptor(eventClass: AEEventClass(kCoreEventClass), eventID: AEEventID(kAEQuitApplication),
                                          targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID),
                                          transactionID: AETransactionID(kAnyTransactionID))
        let open = NSAppleEventDescriptor(eventClass: AEEventClass(kCoreEventClass), eventID: AEEventID(kAEOpenApplication),
                                          targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID),
                                          transactionID: AETransactionID(kAnyTransactionID))
        #expect(QuitFlow.isQuitEvent(quit))
        #expect(!QuitFlow.isQuitEvent(open))
        #expect(!QuitFlow.isQuitEvent(nil))
    }

    @Test func aSecondQuitWhileStoppingIsCancelled() async {
        let record = Record()
        var release: CheckedContinuation<Void, Never>?
        let flow = QuitFlow(gate: await launchedGate(), stop: {
            record.stops += 1
            await withCheckedContinuation { release = $0 }
        }, terminate: { record.terminations += 1 })
        #expect(flow.reply(isQuitEvent: false) == .terminateCancel)
        #expect(await eventually { release != nil })
        #expect(flow.reply(isQuitEvent: false) == .terminateCancel)
        #expect(flow.state == .stopping && record.stops == 1 && record.terminations == 0)
        release?.resume()
        #expect(await eventually { record.terminations == 1 })
    }

    @Test func beforeAnyLaunchWorkNothingIsStopped() {
        let record = Record()
        let flow = QuitFlow(gate: LaunchGate(), stop: { record.stops += 1 }, terminate: { record.terminations += 1 })
        #expect(flow.reply(isQuitEvent: false) == .terminateNow)
        #expect(record.stops == 0)
    }

    @Test func aQuitDuringTheLaunchWaitsForIt() async {
        let record = Record()
        let gate = LaunchGate()
        var finishLaunch: CheckedContinuation<Void, Never>?
        gate.launch { await withCheckedContinuation { finishLaunch = $0 } }
        #expect(await eventually { finishLaunch != nil })
        let flow = QuitFlow(gate: gate, stop: { record.stops += 1 }, terminate: { record.terminations += 1 })
        #expect(flow.reply(isQuitEvent: false) == .terminateCancel)
        for _ in 0..<20 { await Task.yield() }
        #expect(record.stops == 0)                                           // still launching
        finishLaunch?.resume()
        #expect(await eventually { record.terminations == 1 })
        #expect(record.stops == 1)
    }

    /// The real stop over the simulated ports: a boosted display ramps down, its baseline is written and its trigger
    /// removed before the app terminates.
    @Test func theRampedStopLeavesEveryDisplayAtItsBase() async throws {
        let time = ManualTimeSource()
        let shell = TestShell.shell(context: TestShell.context(time: time))
        let gamma = try #require(shell.ports.gamma as? FakeGammaPort)
        let triggers = try #require(shell.ports.triggers as? FakeTriggerFactory)
        await CompositionRoot.runLaunchWork(shell)
        shell.services.boost.setOn(true, source: .panel)
        let boosted = await advance(time, until: { shell.services.boost.status.displays.first?.phase == .boosted })
        #expect(boosted)
        #expect(gamma.writeCount > 0 && triggers.openWindowCount > 0)
        let record = Record()
        let flow = QuitFlow(gate: await launchedGate(), stop: { await shell.runner.stop(within: EngineTiming.quitTimeout) },
                            terminate: { record.terminations += 1 })
        #expect(flow.reply(isQuitEvent: false) == .terminateCancel)
        _ = await advance(time, until: { record.terminations == 1 })
        #expect(record.terminations == 1)
        let id = try #require(shell.ports.displays.displays.first?.ref.id)
        let base = try #require(gamma.base(of: id))
        #expect(gamma.table(of: id).map { TableClassifier.classify($0, expectedBase: base) } == .matchesBase)
        #expect(triggers.openWindowCount == 0)
        #expect(shell.services.settings[EngineRecords.boostMarker] == nil)
    }

    /// Moves `time` in 10 ms steps until `condition` holds (at most 30 s of manual time).
    private func advance(_ time: ManualTimeSource, until condition: () -> Bool) async -> Bool {
        for _ in 0..<3_000 {
            if condition() { return true }
            for _ in 0..<10 { await Task.yield() }
            await time.advance(by: .milliseconds(10))
        }
        return condition()
    }
}
