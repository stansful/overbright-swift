// OverbrightAppShellTests/LaunchCheckSignalsTests.swift — the real wiring's console gate for the launch check
// (ARCHITECTURE.md §7.4 step 1, D27): until Signals has started, `LaunchCheckSignals` reads the console state itself
// (the monitor's snapshot holds only a default before `start()`), so a launch off the console skips the check and runs
// it once the session becomes active; after Signals started, the monitor's snapshot passes through unchanged; events and
// the boost, power and Focus calls reach the monitor. The console read and the start are injected; the real read
// (`sessionIsOnConsole`) is a read-only CoreGraphics call.
import OverbrightBoost
import OverbrightCore
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct LaunchCheckSignalsTests {
    /// The injected answers: whether Signals has started and whether the session is on the console.
    private final class Console {
        var hasStarted = false
        var isOnConsole = true
    }

    private func view(_ base: FakeSystemSignals, _ console: Console) -> LaunchCheckSignals {
        LaunchCheckSignals(base: base, hasStarted: { console.hasStarted }, isOnConsole: { console.isOnConsole })
    }

    @Test func untilSignalsStartedTheConsoleIsReadLive() {
        let base = FakeSystemSignals()
        let console = Console()
        console.isOnConsole = false
        let signals = view(base, console)
        #expect(base.snapshot.isSessionActive)                                // the monitor's default before start()
        #expect(!signals.snapshot.isSessionActive)
        console.isOnConsole = true
        #expect(signals.snapshot.isSessionActive)
        base.snapshot.isScreenLocked = true                                   // the rest is the monitor's
        #expect(signals.snapshot.isScreenLocked)
    }

    @Test func onceSignalsStartedItsSnapshotPassesThrough() {
        let base = FakeSystemSignals()
        let console = Console()
        let signals = view(base, console)
        console.hasStarted = true
        console.isOnConsole = false                                           // no longer read
        #expect(signals.snapshot == base.snapshot)
        #expect(signals.snapshot.isSessionActive)
        base.snapshot.isSessionActive = false
        #expect(signals.snapshot == base.snapshot)
    }

    /// The composition root's launch check over the view: off the console it is skipped (nothing read or restored);
    /// `sessionBecameActive` from the monitor reaches it through the view and the deferred check runs.
    @Test func offTheConsoleTheLaunchCheckIsSkippedUntilTheSessionReturns() async throws {
        let context = TestShell.context()
        var ports = TestShell.ports(context: context)
        let base = try #require(ports.signals as? FakeSystemSignals)
        let gamma = try #require(ports.gamma as? FakeGammaPort)
        let console = Console()
        console.isOnConsole = false
        ports.launchCheckSignals = view(base, console)
        let shell = CompositionRoot.makeShell(context, ports: ports, scriptedStatus: nil)
        #expect(await shell.rescue.runLaunchCheck() == .skippedNotOnConsole)
        #expect(gamma.restoreCount == 0 && shell.rescue.deferredCheck == nil)
        console.isOnConsole = true
        base.emit(.sessionBecameActive)
        let outcome = try #require(await shell.rescue.deferredCheck?.value)
        #expect(outcome != .skippedNotOnConsole)
        #expect(shell.rescue.lastOutcome == outcome)
    }

    @Test func eventsAndCallsReachTheMonitor() {
        let base = FakeSystemSignals()
        let signals = view(base, Console())
        var events: [SystemEvent] = []
        let token = signals.addEventObserver { events.append($0) }
        base.emit(.unlocked)
        #expect(events == [.unlocked])
        signals.setBoostActive(false)
        signals.refreshPowerNow()
        signals.setFocusDirective(.off)
        #expect(base.boostActiveCalls == [false] && base.refreshPowerNowCount == 1 && base.focusDirectives == [.off])
        token.cancel()
        base.emit(.locked)
        #expect(events == [.unlocked])
    }
}
