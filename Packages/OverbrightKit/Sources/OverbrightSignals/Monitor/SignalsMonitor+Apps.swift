// OverbrightSignals/Monitor/SignalsMonitor+Apps.swift — app launches and terminations, and the running conflicts.
// ARCHITECTURE.md §7.1 ("Active Space, app activation, launch, termination"), §7.2, D9.
// Two sources report them: the workspace's did-launch and did-terminate notifications (regular apps only on macOS 27)
// and the KVO of `NSWorkspace.runningApplications` (every app, agent and accessory apps included: most boosters and
// gamma writers run that way, `RunningAppsObserver`). Each report updates the conflicts first, so the snapshot is
// current when the event arrives; then `appLaunched` and `appTerminated` are posted once per process, whichever source
// came first (`AppEventFilter`), and a regular app's termination requests the full-screen re-check.
// Energy (DESIGN.md §17): the list changes 0.3–1 times a second on a busy Mac, so a report does not re-match the whole
// list (≈ 14 ms with the as-built matcher). The conflicts are kept per process: a report drops the processes that
// left and matches only those that joined, each once, whichever source reported it first (a few µs). A launched
// app counts even before the list shows it; a terminated one no longer counts even while the list still shows it. A
// full scan of the list re-syncs at start, on every path into boosting (`setBoostActive(true)`), when the session
// becomes active, after a wake and on a notification without an app, so a change the KVO missed delays a banner only
// until then and never lets a boost start past a conflict.
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
            rescanConflicts()
            post(.appLaunched(bundleID: nil))
            return
        }
        appsChanged(RunningAppsChange(added: [app], removed: []))
    }

    /// The workspace's did-terminate notification.
    func appTerminationNotified(_ app: RunningAppInfo?) {
        guard let app else {
            rescanConflicts()
            post(.appTerminated(bundleID: nil, processID: 0))
            fullScreen.request()
            return
        }
        appsChanged(RunningAppsChange(added: [], removed: [app]))
    }

    /// Launches and terminations from either source: the conflicts first, then each launch and termination posted once,
    /// then the full-screen re-check after a regular app's termination.
    /// Every termination is posted, a background-only process's too (an XPC service, a bundle-less tool): any table
    /// writer's death resets every display, so the engine's 50 ms drift check needs them, and it runs only while a
    /// display is scaled or dimmed (§4.8). The re-check is for regular apps only: another app's window counts as full
    /// screen only while that app is frontmost (`FullScreenDetector.counts`), and when a frontmost accessory app quits,
    /// the next app's activation requests the re-check; a background-only process is never frontmost (C-SIGNALS-1).
    func appsChanged(_ change: RunningAppsChange) {
        followConflicts(launched: change.added, terminated: Set(change.removed.map(\.processID)))
        let launched = change.added.filter { appEvents.shouldPostLaunch($0.processID) }
        let terminated = change.removed.filter { appEvents.shouldPostTermination($0.processID) }
        for app in launched { post(.appLaunched(bundleID: app.bundleID)) }
        for app in terminated { post(.appTerminated(bundleID: app.bundleID, processID: app.processID)) }
        if terminated.contains(where: \.isRegular) { fullScreen.request() }
    }

    /// Follows one launch-and-termination report: terminated processes leave the conflicts, and launched ones not
    /// matched since the last full scan are matched (a process on both sides counts as terminated).
    func followConflicts(launched: [RunningAppInfo], terminated: Set<Int32>) {
        guard let conflictProbe else { return }
        var conflicts = conflictsByPID
        for app in launched where !terminated.contains(app.processID) {
            guard matchedProcesses.insert(app.processID).inserted else { continue }    // the second report of it
            conflicts[app.processID] = conflictProbe.conflict(for: app)
        }
        for processID in terminated {
            conflicts[processID] = nil
            matchedProcesses.remove(processID)
        }
        publishConflicts(conflicts)
    }

    /// Re-scans the whole running list (a full pass of the probe) and publishes its conflicts.
    func rescanConflicts() {
        guard let conflictProbe else { return }
        let scan = conflictProbe.scan()
        matchedProcesses = scan.processIDs
        publishConflicts(Self.byProcess(scan.conflicts))
    }

    /// `conflicts` keyed by process ID (a process listed twice keeps its most severe match).
    static func byProcess(_ conflicts: [ConflictingApp]) -> [Int32: ConflictingApp] {
        Dictionary(conflicts.map { ($0.processID, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Keeps `conflicts` and publishes them, most severe first, when the list changed.
    private func publishConflicts(_ conflicts: [Int32: ConflictingApp]) {
        conflictsByPID = conflicts
        let list = RunningAppsConflictProbe.ordered(conflicts.values)
        guard list != snapshot.conflicts else { return }
        update { $0.conflicts = list }
        record("conflicts.changed", ["count": Double(list.count)])
        log.info("conflicts: \(list.map(\.entryID).joined(separator: ","), privacy: .public)")
    }
}
