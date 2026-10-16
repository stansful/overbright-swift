// OverbrightAppShell/App/QuitFlow.swift — the quit of ARCHITECTURE.md §7.4 (as built in WP0a and kept by WP13), D7.
//
// A quit from inside the app (⌘Q, the panel, the menu, `NSApp.terminate`) is cancelled once; when the launch work is
// still running it waits for it (`LaunchGate`, at most 3 s); then every service stops in reverse order, Boost first,
// within `EngineTiming.quitTimeout` (the ramped stop: ramp to 1 → baselines → triggers removed), and the app
// terminates again, which now goes through. Not `.terminateLater`: on macOS 27.0.1, while AppKit waits for
// `reply(toApplicationShouldTerminate:)` it serves neither the main dispatch queue nor the main actor [VERIFIED in this
// app, WP0a], so no ramp step could run. A quit Apple Event (`kAEQuitApplication`: another app, a script, the Dock,
// Activity Monitor, log out, restart, shut down) is never cancelled, so its sender never sees "User canceled" (-128)
// and a logout is never held up: it terminates at once, and `applicationWillTerminate` runs every `stopNow()`, which
// writes the baselines synchronously. That holds while a user quit is stopping too (its `LaunchGate` wait and the
// ramped stop): a second quit from inside the app is cancelled, a quit Apple Event is not. Before any launch work (a
// command-line mode) nothing is stopped.
import AppKit
import OverbrightBoost
import OverbrightCore
import os

private let log = Log.logger(.app)

/// The quit's state machine (`applicationShouldTerminate`).
final class QuitFlow {
    /// Where a user quit is.
    enum State: Equatable { case running, stopping, stopped }

    private let gate: LaunchGate
    private let stop: () async -> Void
    private let terminate: () -> Void
    /// Where the quit is.
    private(set) var state = State.running

    /// A quit that waits for `gate`, runs `stop` (the ramped stop with its timeout) and then `terminate`s again.
    init(gate: LaunchGate, stop: @escaping () async -> Void, terminate: @escaping () -> Void = { NSApp.terminate(nil) }) {
        self.gate = gate; self.stop = stop; self.terminate = terminate
    }

    /// The quit over `runner`, bounded by `EngineTiming.quitTimeout`.
    convenience init(gate: LaunchGate, runner: ServiceRunner) {
        self.init(gate: gate, stop: { await runner.stop(within: EngineTiming.quitTimeout) })
    }

    /// `applicationShouldTerminate`: `isQuitEvent` is true for a quit Apple Event.
    func reply(isQuitEvent: Bool) -> NSApplication.TerminateReply {
        guard gate.runsTerminateHooks else { return .terminateNow }
        switch state {
        case .stopped:
            return .terminateNow
        case .stopping:
            guard isQuitEvent else { return .terminateCancel }       // a second user quit waits for the first
            log.info("quit: a quit event while stopping terminates now")    // a logout is never held up
            return .terminateNow
        case .running:
            if isQuitEvent { return .terminateNow }
            state = .stopping
            log.info("quit: stopping the services")
            let proceed = { [weak self] in self?.stopThenTerminate() }
            if !gate.defersQuit(reply: { proceed() }) { proceed() }
            return .terminateCancel
        }
    }

    /// Whether the current Apple Event is a quit event (`kAEQuitApplication`).
    static func isQuitEvent(_ event: NSAppleEventDescriptor? = NSAppleEventManager.shared().currentAppleEvent) -> Bool {
        guard let event else { return false }
        return event.eventClass == AEEventClass(kCoreEventClass) && event.eventID == AEEventID(kAEQuitApplication)
    }

    private func stopThenTerminate() {
        Task {
            await stop()
            state = .stopped
            terminate()
        }
    }
}
