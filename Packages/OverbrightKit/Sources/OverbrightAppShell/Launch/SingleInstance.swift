// OverbrightAppShell/Launch/SingleInstance.swift — one engine per user session. ARCHITECTURE.md §7.4, §10.2; D27.
// Seam written by WP0a (§10.0): `SingleInstance.handOverIfRunning(arguments:) -> Bool` is fixed; WP0b wrote the body.
// The shell skips the check for CLI modes and for launches wired to the simulated ports
// (`CompositionRoot.skipsSingleInstanceCheck`), never on the arguments alone.
//
// Another process with our bundle ID and a different PID means two engines would see each other's table writes as
// resets or drift and fight (D27). This launch then asks the running one to show itself — the reopen that Finder or
// Spotlight would send (`applicationShouldHandleReopen`, which shows Welcome, the panel or Settings ▸ General) — and
// exits before it builds any window or touches a display.
//
// The reopen is LaunchServices' own: opening the other instance's bundle URL (`NSWorkspace.open`) activates the copy
// that runs there and sends it the reopen event; no Apple Event is sent from here (the hardened runtime would need an
// entitlement, and the app has none). When both copies share one bundle path (`open -n`), LaunchServices picks the
// instance [U: WP16 checks it on the owner's Mac]. A relaunch after "Move to Applications" names the old process
// with `--after-move <pid>`: that one exits as soon as LaunchServices has answered its relaunch, before it starts any
// service (`ApplicationsMover`), so it is never an engine. This launch waits for it (at most `moveWait`) and never
// hands over to it, also when it is slow to go: handing over to a copy that is exiting would leave nothing running. An
// instance started with `--qa-simulate` (a Debug QA run on the simulated ports, which writes no table) is not an
// engine either: the owner's copy never hands over to an agent's QA run (`ProcessArguments`). Nor is a process of the
// same app running a command-line mode (as built, 2026-10-21): `--monitor` and `--diagnostics` only read, so the app
// starts next to them (HARDWARE-TEST keeps a monitor running through the session); `--restore-gamma` writes tables
// once and quits, so this launch waits for it (at most `restoreWait`) and then starts, never handing over to it.
// `NSRunningApplication` lists such a run too: before this, a monitor started from Terminal made the app hand over to
// it and quit (the owner's report).
import AppKit
import Foundation
import OverbrightCore
import os

private let log = Log.logger(.app)

/// The single-instance check of D27.
enum SingleInstance {
    /// Another Overbright process.
    struct Instance: Equatable {
        /// Its process identifier.
        let processIdentifier: pid_t
        /// Where it runs from (nil when LaunchServices does not say).
        let bundleURL: URL?
        /// Started with `--qa-simulate`: simulated ports, no table writes, not an engine to hand over to.
        var isSimulated = false
        /// Started in a command-line mode (`--monitor`, `--diagnostics`, `--restore-gamma`): no service, no window,
        /// never an engine to hand over to.
        var isCommandLine = false
        /// Started with `--restore-gamma`: the command-line mode that writes tables (dirty-then-restore) and quits;
        /// a launch waits for it instead of starting next to it.
        var restoresGamma = false
    }

    /// What the check reads and does; `live` is the real system, tests pass fakes.
    struct Environment {
        /// This app's bundle identifier (nil outside an app bundle: never a second instance).
        var bundleIdentifier: String?
        /// This process.
        var processIdentifier: pid_t
        /// Every running, not terminated process with `bundleIdentifier`, this one included.
        var running: (_ bundleIdentifier: String) -> [Instance]
        /// Asks `instance` to show itself; false when LaunchServices refused.
        var reopen: (_ instance: Instance) -> Bool
        /// Waits until `pid` has exited, at most `limit`; true when it did.
        var waitForExit: (_ pid: pid_t, _ limit: Duration) -> Bool

        /// The real system.
        static var live: Environment {
            Environment(
                bundleIdentifier: Bundle.main.bundleIdentifier,
                processIdentifier: ProcessInfo.processInfo.processIdentifier,
                running: { id in
                    NSRunningApplication.runningApplications(withBundleIdentifier: id)
                        .filter { !$0.isTerminated }
                        .map { app in
                            Instance(processIdentifier: app.processIdentifier, bundleURL: app.bundleURL,
                                     arguments: ProcessArguments.of(app.processIdentifier).map(LaunchArguments.init))
                        }
                },
                reopen: { instance in
                    guard let url = instance.bundleURL else { return false }
                    return NSWorkspace.shared.open(url)
                },
                waitForExit: { pid, limit in
                    let deadline = Date().addingTimeInterval(limit.timeInterval)
                    while Date() < deadline {
                        // `kill(pid, 0)` probes without signalling; ESRCH = gone. (NSRunningApplication's state is
                        // refreshed by the main run loop, which this launch-time wait does not run.)
                        if kill(pid, 0) != 0, errno == ESRCH { return true }
                        Thread.sleep(forTimeInterval: 0.05)              // launch only, before any UI exists
                    }
                    return false
                })
        }
    }

    /// The launch argument a relaunch after "Move to Applications" carries: the PID of the copy that is quitting.
    static let afterMoveArgument = "--after-move"
    /// How long a relaunch after a move waits for the old copy to quit.
    static let moveWait: Duration = .seconds(5)
    /// How long a launch waits for a running `--restore-gamma` to finish (it restores and verifies every display, then
    /// quits).
    static let restoreWait: Duration = .seconds(5)

    /// True when another Overbright runs in this session and has been asked to reopen: the caller then exits.
    static func handOverIfRunning(arguments: LaunchArguments = .current) -> Bool {
        handOverIfRunning(arguments: arguments, environment: .live)
    }

    /// The check over `environment` (tests: `secondInstanceHandsOverAndExits`, `aMonitorIsNotAnEngine`).
    static func handOverIfRunning(arguments: LaunchArguments, environment: Environment) -> Bool {
        guard !arguments.isCommandLineMode, let bundleID = environment.bundleIdentifier else { return false }
        let others = environment.running(bundleID)
            .filter { $0.processIdentifier != environment.processIdentifier && !$0.isSimulated }
        // A command-line run (`--monitor`, `--diagnostics`, `--restore-gamma`) starts no service: never an engine.
        var engines = others.filter { !$0.isCommandLine }
        if let moved = arguments.int(after: afterMoveArgument).flatMap({ pid_t(exactly: $0) }),   // never traps (§9.2)
           engines.contains(where: { $0.processIdentifier == moved }) {
            // The copy that moved itself exits before it starts anything: never an engine to hand over to.
            if !environment.waitForExit(moved, moveWait) {
                log.error("launch.secondInstance: the moved copy \(moved, privacy: .public) is still exiting; carrying on")
            }
            engines.removeAll { $0.processIdentifier == moved }
        }
        if let other = engines.first {
            let reopened = environment.reopen(other)
            log.info("launch.secondInstance: Overbright already runs as \(other.processIdentifier, privacy: .public); reopen \(reopened ? "sent" : "refused", privacy: .public), exiting")
            return true
        }
        // This launch starts. A `--restore-gamma` run writes tables and quits: let it finish first, so its restore and
        // this engine's launch check never read or write the same table at once (handing over would leave nothing
        // running).
        for restore in others where restore.restoresGamma {
            if !environment.waitForExit(restore.processIdentifier, restoreWait) {
                log.error("launch.secondInstance: --restore-gamma (\(restore.processIdentifier, privacy: .public)) is still running; carrying on")
            }
        }
        return false
    }
}

extension SingleInstance.Instance {
    /// The instance `arguments` describe (another process's launch arguments; nil when they cannot be read, which
    /// counts as an engine: the safe direction is one engine too few, never two).
    init(processIdentifier: pid_t, bundleURL: URL?, arguments: LaunchArguments?) {
        self.init(processIdentifier: processIdentifier, bundleURL: bundleURL,
                  isSimulated: arguments?.qaSimulates ?? false,
                  isCommandLine: arguments?.isCommandLineMode ?? false,
                  restoresGamma: arguments?.restoresGamma ?? false)
    }
}
