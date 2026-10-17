// OverbrightSignals/Monitor/SignalsMonitor+Notifications.swift — the always-on notification sources. ARCHITECTURE.md
// §7.1 (event wiring table), §7.2, §7.3, D9, D27.
// Thread: workspace notifications are registered with `queue: .main` and handled on the main actor
// (`MainActor.assumeIsolated` with the queue's guarantee, Cranny's pattern). Distributed ones go through
// `SignalsPlatform.observeDistributed` (immediate delivery, `DistributedObserver`). Thermal state and Low Power Mode
// are posted on ANY thread: they use `queue: nil` and a `@Sendable` block that hops through `MainHop`, never a
// main-actor `@objc` selector (§8.1 rule 2; `ThermalOffMainTests`, `LowPowerOffMainTests`). The handlers update the
// snapshot first, then post the event (synchronous delivery); a shield's handlers then stop or resume the boost-only
// sources (`shieldChanged`). Launches and terminations go through `SignalsMonitor+Apps.swift`.
import AppKit
import Foundation
import OverbrightCore
import os

private let log = Log.logger(.signals)

extension SignalsMonitor {
    /// Distributed notification names (public strings, posted by loginwindow, the screensaver and ColorSync).
    nonisolated enum DistributedName {
        /// `com.apple.screenIsLocked`.
        static let locked = Notification.Name("com.apple.screenIsLocked")
        /// `com.apple.screenIsUnlocked`.
        static let unlocked = Notification.Name("com.apple.screenIsUnlocked")
        /// `com.apple.screensaver.didstart`.
        static let screensaverStarted = Notification.Name("com.apple.screensaver.didstart")
        /// `com.apple.screensaver.didstop`.
        static let screensaverStopped = Notification.Name("com.apple.screensaver.didstop")
        /// ColorSync's `kColorSyncDisplayDeviceProfilesNotification`.
        static let displayProfile = Notification.Name("com.apple.ColorSync.DisplayProfileNotification")
    }

    /// `NSProcessInfoPowerStateDidChangeNotification` (Low Power Mode; posted on any thread).
    nonisolated static let lowPowerModeChanged = Notification.Name.NSProcessInfoPowerStateDidChange

    /// Registers every always-on notification.
    func registerNotifications() {
        let workspace = platform.workspaceCenter
        onMain(.workspaceNotifications, workspace, NSWorkspace.willSleepNotification) { monitor, _ in
            monitor.update { $0.isSystemSleeping = true }
            monitor.post(.willSleep)
            monitor.shieldChanged()
        }
        onMain(.workspaceNotifications, workspace, NSWorkspace.didWakeNotification) { monitor, _ in
            monitor.update { $0.isSystemSleeping = false }
            monitor.rescanConflicts()                                     // a full scan after the sleep
            monitor.post(.didWake)
            monitor.didWake()
        }
        onMain(.workspaceNotifications, workspace, NSWorkspace.screensDidSleepNotification) { monitor, _ in
            monitor.update { $0.areDisplaysAsleep = true }
            monitor.post(.screensDidSleep)
            monitor.shieldChanged()
        }
        onMain(.workspaceNotifications, workspace, NSWorkspace.screensDidWakeNotification) { monitor, _ in
            monitor.update { $0.areDisplaysAsleep = false }
            monitor.post(.screensDidWake)
            monitor.shieldChanged()
            monitor.fullScreen.request()
        }
        onMain(.workspaceNotifications, workspace, NSWorkspace.sessionDidResignActiveNotification) { monitor, _ in
            monitor.update { $0.isSessionActive = false }
            monitor.post(.sessionResigned)
            monitor.shieldChanged()
        }
        onMain(.workspaceNotifications, workspace, NSWorkspace.sessionDidBecomeActiveNotification) { monitor, _ in
            monitor.update { $0.isSessionActive = true }
            monitor.rescanConflicts()                                     // back on the console: a full scan
            monitor.post(.sessionBecameActive)
            monitor.shieldChanged()
            monitor.fullScreen.request()
        }
        onMain(.workspaceNotifications, workspace, NSWorkspace.activeSpaceDidChangeNotification) { monitor, _ in
            monitor.post(.activeSpaceChanged)
            monitor.fullScreen.request()
        }
        onMain(.workspaceNotifications, workspace, NSWorkspace.didActivateApplicationNotification) { monitor, app in
            monitor.post(.appActivated(bundleID: app?.bundleID))
            monitor.fullScreen.request()
        }
        // Regular apps only; agent and accessory apps reach `appsChanged` through the running list's KVO.
        onMain(.workspaceNotifications, workspace, NSWorkspace.didLaunchApplicationNotification) { monitor, app in
            monitor.appLaunchNotified(app)
        }
        onMain(.workspaceNotifications, workspace, NSWorkspace.didTerminateApplicationNotification) { monitor, app in
            monitor.appTerminationNotified(app)
        }
        observeRunningApplications()
        let accessibility = NSWorkspace.accessibilityDisplayOptionsDidChangeNotification
        onMain(.workspaceNotifications, workspace, accessibility) { monitor, _ in
            let reduceMotion = monitor.platform.reduceMotion()
            monitor.update { $0.reduceMotion = reduceMotion }
            monitor.post(.accessibilityDisplayOptionsChanged)
        }

        onDistributed(DistributedName.locked) { monitor in
            monitor.update { $0.isScreenLocked = true }
            monitor.post(.locked)
            monitor.shieldChanged()
        }
        onDistributed(DistributedName.unlocked) { monitor in
            monitor.update { $0.isScreenLocked = false }
            monitor.post(.unlocked)
            monitor.shieldChanged()
        }
        onDistributed(DistributedName.screensaverStarted) { monitor in
            monitor.update { $0.isScreensaverRunning = true }
            monitor.post(.screensaverStarted)
            monitor.shieldChanged()
        }
        onDistributed(DistributedName.screensaverStopped) { monitor in
            monitor.update { $0.isScreensaverRunning = false }
            monitor.post(.screensaverStopped)
            monitor.shieldChanged()
        }
        onDistributed(DistributedName.displayProfile) { monitor in
            monitor.post(.colorProfileChanged)
        }

        let local = platform.localCenter
        // Displays owns `screenParametersChanged` (§7.1); Signals only re-checks full screen.
        onMain(.processNotifications, local, NSApplication.didChangeScreenParametersNotification) { monitor, _ in
            monitor.fullScreen.request()
        }
        onAnyThread(.processNotifications, local, ProcessInfo.thermalStateDidChangeNotification) { monitor in
            monitor.thermalStateChanged()
        }
        onAnyThread(.processNotifications, local, Self.lowPowerModeChanged) { monitor in
            monitor.powerSourceChanged()
        }
        if #available(macOS 26.0, *) {
            onMain(.processNotifications, local, NSApplication.ShouldBeginSuppressingHighDynamicRangeContent.name) {
                monitor, _ in monitor.hdrSuppressionChanged(true)
            }
            onMain(.processNotifications, local, NSApplication.ShouldEndSuppressingHighDynamicRangeContent.name) {
                monitor, _ in monitor.hdrSuppressionChanged(false)
            }
        }
    }

    // MARK: Handlers shared with the IOKit callbacks

    /// A power-source switch, a battery-percent change or a Low Power Mode change: read synchronously, follow the
    /// source with the battery-percent source, post `powerChanged` when anything changed.
    func powerSourceChanged() {
        guard isStarted else { return }
        let before = snapshot.power
        let power = platform.readPower()
        update { $0.power = power }
        applyBoostSources()
        guard power != before else { return }
        record("signals.power", ["battery": power.source == .battery ? 1 : 0, "percent": Double(power.batteryPercent ?? -1),
                                 "lowPower": power.isLowPowerMode ? 1 : 0])
        post(.powerChanged)
    }

    /// The thermal state changed (posted on any thread; hopped here).
    func thermalStateChanged() {
        guard isStarted else { return }
        let level = platform.thermalLevel()
        guard level != snapshot.thermal else { return }
        update { $0.thermal = level }
        record("signals.thermal", ["level": Double(level.rawValue)])
        post(.thermalChanged(level))
    }

    /// macOS 26+ asked apps to suppress HDR, or stopped asking: a reason only, never a stop or an escalation.
    func hdrSuppressionChanged(_ suppressed: Bool) {
        update { $0.isHDRSuppressed = suppressed }
        record("signals.hdrSuppression", ["on": suppressed ? 1 : 0])
        log.info("HDR suppression \(suppressed ? "began" : "ended", privacy: .public)")
        post(suppressed ? .hdrSuppressionBegan : .hdrSuppressionEnded)
    }

    /// After a system wake: the power source may have changed, Spaces settle, and the boost-only sources follow the
    /// shield (`willSleep` suspended them; reading the power re-applies them, and idle tracking that resumes reads the
    /// idle time). A deadline that ran across the sleep (no `willSleep` seen) is re-read too.
    func didWake() {
        let wasTracking = isIdleTracking
        powerSourceChanged()
        fullScreen.request()
        if wasTracking { evaluateIdle() }
    }

    // MARK: Registration

    /// Observes `name` on `center` on the main queue; `handle` runs on the main actor with the notification's app
    /// (read on the posting queue: `NSRunningApplication` is thread-safe and `Sendable`).
    private func onMain(_ source: SignalSource, _ center: NotificationCenter, _ name: Notification.Name,
                        _ handle: @escaping @MainActor (SignalsMonitor, RunningAppInfo?) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self, platform] notification in
            let app = platform.application(in: notification)
            MainActor.assumeIsolated {                                    // queue: .main
                guard let self, self.isStarted else { return }
                handle(self, app)
            }
        }
        notificationTokens[source, default: []].append(ObservationToken { center.removeObserver(token) })
    }

    /// Observes the distributed notification `name` (delivered immediately, on the main actor).
    private func onDistributed(_ name: Notification.Name, _ handle: @escaping @MainActor (SignalsMonitor) -> Void) {
        let token = platform.observeDistributed(name) { [weak self] in
            guard let self, self.isStarted else { return }
            handle(self)
        }
        notificationTokens[.distributedNotifications, default: []].append(token)
    }

    /// Observes `name` posted on any thread: a `@Sendable` block on the posting thread hops to the main actor.
    private func onAnyThread(_ source: SignalSource, _ center: NotificationCenter, _ name: Notification.Name,
                             _ handle: @escaping @MainActor @Sendable (SignalsMonitor) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: nil, using: Self.hop { [weak self] in
            guard let self, self.isStarted else { return }
            handle(self)
        })
        notificationTokens[source, default: []].append(ObservationToken { center.removeObserver(token) })
    }

    /// The any-thread notification block: nonisolated (a closure written in a main-actor method would be inferred
    /// `@MainActor` and trap on the posting thread), hopping through `MainHop`.
    nonisolated static func hop(_ body: @escaping @MainActor @Sendable () -> Void) -> @Sendable (Notification) -> Void {
        { _ in MainHop.run(body) }
    }
}
