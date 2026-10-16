// OverbrightAppShell/App/LaunchSequence.swift — the launch order of ARCHITECTURE.md §7.4, with its effects injected
// (the app delegate passes the real ones; `LaunchOrderTests` pass recorders). D24, D27.
//
// A Release build given a Debug-only switch exits with `EX_USAGE` before anything else → `ShellDefaults` and the
// composition root build the hub (no I/O) → command-line modes (`--diagnostics`, `--monitor`, `--restore-gamma`) run
// and quit here, before any service starts, any window opens or any preference is written → single instance
// (skipped for command-line modes and launches wired to the simulated ports) → move to Applications → settings
// upgrade → controllers, router connection and status item → `LaunchGate`: the launch check, then the services
// (Displays first, Boost last) → QA hooks (Debug) → launch UI.

/// Runs the launch steps in order.
struct LaunchSequence {
    /// What each step does.
    struct Effects {
        /// The Debug-only switches this build refuses (empty: none).
        var refusedSwitches: () -> [String]
        /// Logs and exits with `EX_USAGE` (in the app it does not return).
        var refuse: ([String]) -> Void
        /// `ShellDefaults`, the context, the ports and the hub.
        var makeShell: () -> Shell
        /// Runs a command-line mode, which quits by itself; false when the launch is not one.
        var runCommandLineMode: (Shell) -> Bool
        /// Hands over to another running Overbright, which shows itself; false when this launch carries on.
        var handOver: (Shell) -> Bool
        /// The move-to-Applications offer (a move relaunches and exits inside it).
        var offerMove: (Shell) -> Void
        /// The settings upgrade.
        var upgradeSettings: (Shell) -> Void
        /// The controllers, the router connection, the status item, the Dock and the HUD.
        var buildControllers: (Shell) -> Void
        /// The launch check, then every service (asynchronous; `LaunchGate`).
        var startLaunchWork: (Shell) -> Void
        /// Debug QA hooks.
        var applyQAHooks: (Shell) -> Void
        /// The launch UI.
        var showLaunchUI: (Shell) -> Void
        /// Called with every step that runs, before it runs (logs, tests).
        var willRun: (LaunchStep) -> Void = { _ in }
    }

    /// Runs the launch; returns the shell when the app keeps running, nil after a refusal, a command-line mode or a
    /// hand-over.
    @discardableResult
    static func run(_ effects: Effects) -> Shell? {
        effects.willRun(.refuseDebugSwitches)
        let refused = effects.refusedSwitches()
        if !refused.isEmpty {
            effects.refuse(refused)
            return nil
        }
        effects.willRun(.servicesHub)
        let shell = effects.makeShell()
        effects.willRun(.commandLineModes)
        if effects.runCommandLineMode(shell) { return nil }
        effects.willRun(.singleInstance)
        if effects.handOver(shell) { return nil }
        let rest: [(LaunchStep, (Shell) -> Void)] = [
            (.moveToApplications, effects.offerMove), (.settingsUpgrade, effects.upgradeSettings),
            (.controllers, effects.buildControllers), (.launchWork, effects.startLaunchWork),
            (.qaHooks, effects.applyQAHooks), (.launchUI, effects.showLaunchUI),
        ]
        for (step, perform) in rest {
            effects.willRun(step)
            perform(shell)
        }
        return shell
    }
}
