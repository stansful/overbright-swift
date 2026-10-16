// OverbrightSignals/Monitor/SignalsMonitor+Apps.swift — app launches and terminations, and the running conflicts.
// ARCHITECTURE.md §7.1 ("Active Space, app activation, launch, termination"), §7.2, D9.
// Two sources report them: the workspace's did-launch and did-terminate notifications (regular apps only on macOS 27)
// and the KVO of `NSWorkspace.runningApplications` (every app, agent and accessory apps included: most boosters and
// gamma writers run that way, `RunningAppsObserver`). Each report re-reads the conflicts first, so the snapshot is
// current when the event arrives; then `appLaunched` and `appTerminated` are posted once per process, whichever source
// came first (`AppEventFilter`), and a termination requests the full-screen re-check.
// Thread: main (both sources deliver on the main run loop).
import Foundation
import OverbrightCore
import os

private let log = Log.logger(.signals)

extension SignalsMonitor {
    /// Observes the running list (an always-on workspace source: KVO costs nothing until the list changes).
    func observeRunningApplications() {
        let token = platform.observeRunningApplications { [weak self] change in
            guard let self, self.isStarted else { return }
            self.appsChanged(change)
        }
        notificationTokens[.workspaceNotifications, default: []].append(token)
    }

    /// The workspace's did-launch notification.
    func appLaunchNotified(_ app: RunningAppInfo?) {
        guard let app else {                                     // no application to tell apart: post as reported
            refreshConflicts(launched: [], terminated: [])
            post(.appLaunched(bundleID: nil))
            return
        }
        appsChanged(RunningAppsChange(added: [app], removed: []))
    }

    /// The workspace's did-terminate notification.
    func appTerminationNotified(_ app: RunningAppInfo?) {
        guard let app else {
            refreshConflicts(launched: [], terminated: [])
            post(.appTerminated(bundleID: nil, processID: 0))
            fullScreen.request()
            return
        }
        appsChanged(RunningAppsChange(added: [], removed: [app]))
    }

    /// Launches and terminations from either source: the conflicts first, then each launch and termination posted once,
    /// then the full-screen re-check after a termination.
    func appsChanged(_ change: RunningAppsChange) {
        refreshConflicts(launched: change.added, terminated: Set(change.removed.map(\.processID)))
        let launched = change.added.filter { appEvents.shouldPostLaunch($0.processID) }
        let terminated = change.removed.filter { appEvents.shouldPostTermination($0.processID) }
        for app in launched { post(.appLaunched(bundleID: app.bundleID)) }
        for app in terminated { post(.appTerminated(bundleID: app.bundleID, processID: app.processID)) }
        if !terminated.isEmpty { fullScreen.request() }
    }

    /// Re-reads the running conflicts after a launch or termination and publishes them.
    func refreshConflicts(launched: [RunningAppInfo], terminated: Set<Int32>) {
        guard let conflictProbe else { return }
        let conflicts = conflictProbe.runningConflicts(launched: launched, terminated: terminated)
        guard conflicts != snapshot.conflicts else { return }
        update { $0.conflicts = conflicts }
        record("conflicts.changed", ["count": Double(conflicts.count)])
        log.info("conflicts: \(conflicts.map(\.entryID).joined(separator: ","), privacy: .public)")
    }
}
