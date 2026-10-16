// OverbrightAppShell/App/Shell.swift — what the composition root builds: the services hub, the ports behind it, the
// lifecycle order and the launch rescue. ARCHITECTURE.md §3.11, §7.4, §10.0 (shared shell file, contract owner),
// §10.15.
import OverbrightBoost
import OverbrightCore

/// What the composition root builds.
struct Shell {
    /// The hub every module reads.
    let services: OverbrightServices
    /// The ports behind it.
    let ports: ShellPorts
    /// Start order (Boost last); stop runs in reverse.
    let lifecycle: [any ServiceLifecycle]
    /// The launch check and `--restore-gamma`.
    let rescue: LaunchRescue
}
