// OverbrightAppShellTests/LifecycleOrderTests.swift — the services start Displays → Triggers → Signals → FillLight →
// HotKeys → Updates → Intents → Boost last and stop in reverse, Boost first (ARCHITECTURE.md §7.4, §10.15, D7); the
// launch check's outcome reaches the engine before it starts; a hung stop never holds the quit past its limit; a stop
// during a service's start stops that service once it started; Displays' events reach every display controller before
// the relay returns (§4.3, §7.1, WP2's acceptance item).
import Foundation
import OverbrightBoost
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightAppShell

/// A service that records its calls into a shared log.
@MainActor private final class RecordingService: ServiceLifecycle {
    let serviceName: String
    let log: CallLog
    var hangsOnStop = false
    var suspendsOnStart = false
    private var hung: CheckedContinuation<Void, Never>?
    private var starting: CheckedContinuation<Void, Never>?

    init(_ name: String, log: CallLog) { serviceName = name; self.log = log }

    func start() async {
        log.calls.append("start \(serviceName)")
        if suspendsOnStart { await withCheckedContinuation { starting = $0 } }    // like the engine's cache attach
    }
    func stop() async {
        log.calls.append("stop \(serviceName)")
        if hangsOnStop { await withCheckedContinuation { hung = $0 } }
    }
    func stopNow() { log.calls.append("stopNow \(serviceName)") }
    func release() { hung?.resume(); hung = nil }
    func finishStart() { starting?.resume(); starting = nil }
}

@MainActor private final class CallLog { var calls: [String] = [] }

@MainActor @Suite struct LifecycleOrderTests {
    private func stack(_ log: CallLog) -> (ServiceStack, [ServiceStack.Role: RecordingService]) {
        var services: [ServiceStack.Role: RecordingService] = [:]
        for role in ServiceStack.Role.allCases { services[role] = RecordingService(role.rawValue, log: log) }
        let stack = ServiceStack(displays: services[.displays], triggers: services[.triggers],
                                 signals: services[.signals], fillLight: services[.fillLight],
                                 hotKeys: services[.hotKeys], updates: services[.updates],
                                 intents: services[.intents], boost: services[.boost])
        return (stack, services)
    }

    @Test func servicesStartInOrderBoostLastAndStopInReverseBoostFirst() async {
        let log = CallLog()
        let (stack, _) = stack(log)
        let runner = ServiceRunner(stack: stack, time: ManualTimeSource(), journal: RingBufferJournal())
        await runner.start(beforeBoost: { log.calls.append("launch check outcome") })
        let names = ["displays", "triggers", "signals", "fillLight", "hotKeys", "updates", "intents"]
        #expect(log.calls == names.map { "start \($0)" } + ["launch check outcome", "start boost"])
        log.calls = []
        #expect(await runner.stop(within: .seconds(1)))
        #expect(log.calls == (["boost"] + names.reversed()).map { "stop \($0)" })
        log.calls = []
        runner.stopNow()                                                   // applicationWillTerminate after the stop
        #expect(log.calls.first == "stopNow boost" && log.calls.last == "stopNow displays")
    }

    @Test func theAppsWiringOrdersItsServicesTheSameWay() {
        #expect(ServiceStack.Role.allCases.map(\.rawValue)
            == ["displays", "triggers", "signals", "fillLight", "hotKeys", "updates", "intents", "boost"])
        // Under --qa-simulate the display ports are plain fakes: Fill Light, shortcuts, updates, the publish point and
        // the engine remain, in the same order.
        let shell = TestShell.shell()
        #expect(shell.lifecycle.map(\.serviceName) == ["FillLight", "HotKeys", "Updates", "Intents", "boost"])
        #expect(shell.stack.stopOrder.first is BoostEngine)
    }

    @Test func nothingStopsBeforeAnythingStarted() async {
        let log = CallLog()
        let (stack, _) = stack(log)
        let runner = ServiceRunner(stack: stack, time: ManualTimeSource(), journal: RingBufferJournal())
        runner.stopNow()
        #expect(await !runner.stop(within: .seconds(1)))
        #expect(log.calls.isEmpty)
    }

    /// The quit waits at most its limit for the ramped stop; the services that did not stop then get `stopNow()`.
    @Test func aHungStopGivesUpAtTheLimit() async {
        let log = CallLog()
        let (stack, services) = stack(log)
        services[.signals]?.hangsOnStop = true
        let time = ManualTimeSource()
        let runner = ServiceRunner(stack: stack, time: time, journal: RingBufferJournal())
        await runner.start()
        let stopping = Task { await runner.stop(within: EngineTiming.quitTimeout) }
        #expect(await eventually { time.sleeperCount == 1 && log.calls.last == "stop signals" })
        await time.advance(by: EngineTiming.quitTimeout)
        #expect(await stopping.value == false)
        #expect(!log.calls.contains("stop displays"))
        runner.stopNow()
        #expect(log.calls.contains("stopNow displays"))
        services[.signals]?.release()
    }

    /// A stop (a signal, a quit) while a service's `start()` is suspended reaches that service before it has started;
    /// once its start returns, the runner stops it (`stopNow()`) and starts nothing after it.
    @Test func aStopDuringAStartStopsThatServiceOnceItStarted() async {
        let log = CallLog()
        let (stack, services) = stack(log)
        services[.signals]?.suspendsOnStart = true
        let runner = ServiceRunner(stack: stack, time: ManualTimeSource(), journal: RingBufferJournal())
        let starting = Task { await runner.start() }
        #expect(await eventually { log.calls.last == "start signals" })
        #expect(await runner.stop(within: .seconds(1)))
        #expect(log.calls.contains("stop signals") && runner.phase == .stopped)
        log.calls = []
        services[.signals]?.finishStart()
        await starting.value
        #expect(log.calls == ["stopNow signals"])                           // nothing started after the stop
        #expect(runner.phase == .stopped)
    }

    /// The launch work: the launch check runs before any service, and its outcome reaches the engine after the
    /// directory lists the displays and before the engine starts (WP5's `applyLaunchCheck`).
    @Test func theLaunchWorkChecksFirstThenStartsEveryService() async throws {
        let shell = TestShell.shell()
        let gamma = try #require(shell.ports.gamma as? FakeGammaPort)
        let id = try #require(shell.ports.displays.facts(for: DisplayFixture.Keys.builtIn)?.ref.id)
        let base = try #require(gamma.base(of: id))
        gamma.foreignWrite(GammaTable(red: base.red.map { $0 * 1.4 }, green: base.green.map { $0 * 1.4 },
                                      blue: base.blue.map { $0 * 1.4 }), to: id)
        await CompositionRoot.runLaunchWork(shell)
        #expect(shell.rescue.lastOutcome != nil)
        #expect(gamma.restoreCount == 1)                                  // the residue was rescued before the services
        #expect(shell.runner.phase == .started)
        #expect(shell.services.boost.status.isReady)
        #expect(gamma.table(of: id).map { TableClassifier.classify($0, expectedBase: base) } == .matchesBase)
    }

    /// WP2: a `displayRemoved` from the directory reaches every display controller synchronously: the display is gone
    /// from the engine before the relay returns.
    @Test func displayEventsReachTheEngineBeforeTheRelayReturns() async throws {
        let fixture = DisplayFixture.sidecar
        let shell = TestShell.shell(fixture)
        let signals = try #require(shell.ports.signals as? FakeSystemSignals)
        var handlers: [@MainActor (SystemEvent) -> Void] = []
        let relay = CompositionRoot.relayDisplayEvents(from: { handler in
            handlers.append(handler)
            return ObservationToken { handlers.removeAll() }
        }, to: { signals.emit($0) })
        await CompositionRoot.runLaunchWork(shell)
        #expect(shell.services.boost.status.displays.count == 2)
        let sidecar = try #require(shell.ports.displays.facts(for: DisplayFixture.Keys.sidecar)?.ref.id)
        for handler in handlers { handler(.displayRemoved(sidecar)) }
        #expect(!(shell.engine?.status.displays.contains { $0.key == DisplayFixture.Keys.sidecar } ?? true))
        relay.cancel()
        #expect(handlers.isEmpty)
    }
}
