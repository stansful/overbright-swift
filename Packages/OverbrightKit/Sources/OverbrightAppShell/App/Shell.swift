// OverbrightAppShell/App/Shell.swift — what the composition root builds: the services hub, the ports behind it, the
// ordered services, the launch rescue, the engine's safety net and the control's publish point. ARCHITECTURE.md §3.11,
// §7.4, §10.0 (shared shell file), §10.15.
import OverbrightBoost
import OverbrightCore

/// What the composition root builds.
struct Shell {
    /// The hub every module reads.
    let services: OverbrightServices
    /// The ports behind it.
    let ports: ShellPorts
    /// The services that start and stop, by role (Boost last).
    let stack: ServiceStack
    /// Starts and stops `stack` (the launch work, the quit, the signal handlers).
    let runner: ServiceRunner
    /// The launch check, `--restore-gamma` and the deferred check on the session's return.
    let rescue: LaunchRescue
    /// The engine (nil under `--qa-state`, which shows a scripted status instead).
    let engine: BoostEngine?
    /// TERM, INT and HUP: baselines at once, the ramped stop, exit (installed by the launch work; nil without an
    /// engine). Kept for the life of the process: its sources set the signals to SIG_IGN.
    let signalHandlers: SignalHandlers?

    /// Start order (Boost last); stop runs in reverse.
    var lifecycle: [any ServiceLifecycle] { stack.startOrder }
}
