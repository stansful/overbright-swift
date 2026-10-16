// OverbrightSignals/Conflicts/WorkspaceRunningApps.swift — the live `RunningAppsSource`. ARCHITECTURE.md §7.2.
// A bundle-less command-line tool that creates an `NSApplication` (how some boosters run) is listed too, with a nil
// bundle ID and its executable URL [VERIFIED], so executable-name entries match it.
// Thread: main (`NSWorkspace`), except `scanProcesses()`, which runs off the main actor.
import AppKit

/// Reads `NSWorkspace` and the disk.
final class WorkspaceRunningApps: RunningAppsSource {
    /// Touches nothing until a method is called.
    init() {}

    /// `NSWorkspace.shared.runningApplications`.
    func runningApplications() -> [RunningAppInfo] {
        NSWorkspace.shared.runningApplications.map(RunningAppInfo.init)
    }

    /// The signing team (Security framework, read from disk).
    func teamID(ofBundleAt url: URL) -> String? { CodeSigningTeam.teamID(ofBundleAt: url) }

    /// The libproc scan.
    func scanProcesses() async -> [ProcessScanner.Process] { await ProcessScanner.scan() }
}
