// OverbrightSignals/Conflicts/RunningAppsSource.swift — what the conflict probe reads. ARCHITECTURE.md §7.2, D21.
// Thread: main for the running-app list (`NSWorkspace.runningApplications` is KVO-updated on the main run loop); the
// process scan runs off the main actor. The live implementation is `WorkspaceRunningApps`; tests use a fake.
import Foundation

/// Running applications, signing teams and the libproc fallback.
@MainActor protocol RunningAppsSource: AnyObject {
    /// `NSWorkspace.runningApplications` (≈ 0.04 ms, no permission).
    func runningApplications() -> [RunningAppInfo]
    /// The signing team of a bundle on disk.
    func teamID(ofBundleAt url: URL) -> String?
    /// Every process by executable path (on demand only, off the main actor).
    func scanProcesses() async -> [ProcessScanner.Process]
}
