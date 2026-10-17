// OverbrightSignals/Monitor/SignalsPlatform.swift — everything `SignalsMonitor` reads from or registers with the system.
// ARCHITECTURE.md §7.1, D21 (the engine and its signals are built on ports with fakes).
// Thread: main. The live implementation is `LiveSignalsPlatform`; constructing it touches nothing. Tests pass private
// notification centers (the distributed ones too) and scripted reads, so no test observes the real workspace, IOKit
// or CoreMediaIO.
import Foundation
import OverbrightCore

/// The system as `SignalsMonitor` sees it.
@MainActor protocol SignalsPlatform: AnyObject, Sendable {
    /// `NSWorkspace.shared.notificationCenter` (sleep/wake, screens, session, Space, apps, accessibility).
    var workspaceCenter: NotificationCenter { get }
    /// `NotificationCenter.default` (screen parameters, thermal, Low Power, HDR suppression).
    var localCenter: NotificationCenter { get }
    /// Our own process (never full screen, never a conflict).
    var ownProcessID: Int32 { get }
    /// The camera devices of the Fill Light rule.
    var cameras: any CameraDevices { get }

    /// On the console, and locked, at launch (`CGSessionCopyCurrentDictionary`).
    func sessionState() -> SessionState
    /// The synchronous power read (`IOPSCopyPowerSourcesInfo` + Low Power Mode).
    func readPower() -> PowerState
    /// `ProcessInfo.thermalState`.
    func thermalLevel() -> ThermalLevel
    /// System Settings ▸ Accessibility ▸ Reduce motion.
    func reduceMotion() -> Bool
    /// macOS 26+: `NSApplication.applicationShouldSuppressHighDynamicRangeContent`; false before 26.
    func isHDRSuppressed() -> Bool
    /// `NSWorkspace.frontmostApplication`.
    func frontmostApplication() -> RunningAppInfo?
    /// `NSWorkspace.runningApplications`.
    func runningApplications() -> [RunningAppInfo]
    /// The process IDs among `candidates` that are regular (Dock) apps of `runningApplications()`: all the full-screen
    /// check needs from the running list (the owners of the windows it judges), without reading every app.
    func regularProcessIDs(among candidates: Set<Int32>) -> Set<Int32>
    /// Observes `NSWorkspace.runningApplications` by KVO (`.old`, `.new`): the apps that joined and left, on the main
    /// actor. It also reports the agent and accessory apps the launch and termination notifications miss.
    func observeRunningApplications(_ handler: @escaping @MainActor @Sendable (RunningAppsChange) -> Void)
        -> ObservationToken
    /// The application of a workspace launch, termination or activation notification. Nonisolated: it runs on the
    /// posting queue, before the hop to the main actor.
    nonisolated func application(in notification: Notification) -> RunningAppInfo?
    /// The Dock's process (its windows never count as full screen).
    func dockProcessID() -> Int32?
    /// Every screen in CG global coordinates with its notch band.
    func screens() -> [FullScreenDetector.Display]
    /// `NSScreen.screensHaveSeparateSpaces` (Desktop & Dock ▸ Displays have separate Spaces; off: one menu bar, on the
    /// main display only).
    func screensHaveSeparateSpaces() -> Bool
    /// The window list (off the main actor in the live implementation). `windowServerPID`: the WindowServer's PID from
    /// an earlier snapshot, so it is looked up at most once per session.
    func windowList(windowServerPID: Int32?) async -> WindowListSnapshot
    /// Processes holding a display-sleep assertion; nil when the read fails.
    func displaySleepHolders() -> Set<Int32>?
    /// Seconds since the last input event of the session; nil when unreadable.
    func secondsSinceLastInput() -> Double?
    /// `LSApplicationCategoryType` of a bundle.
    func appCategory(bundleURL: URL) -> String?
    /// Observes a distributed notification (lock, screensaver, ColorSync) with immediate delivery, whatever the
    /// app's activation state; `handler` runs on the main actor.
    func observeDistributed(_ name: Notification.Name, _ handler: @escaping @MainActor @Sendable () -> Void)
        -> ObservationToken
    /// Starts the IOKit source-switch notification (adapter ↔ battery ↔ UPS); nil when unavailable.
    func observePowerSourceSwitches(_ handler: @escaping @MainActor @Sendable () -> Void) -> ObservationToken?
    /// Starts the IOKit every-change notification (battery percent); nil when unavailable.
    func observeBatteryChanges(_ handler: @escaping @MainActor @Sendable () -> Void) -> ObservationToken?
}

extension SignalsPlatform {
    /// The regular apps among `candidates`, filtered from `runningApplications()`.
    func regularProcessIDs(among candidates: Set<Int32>) -> Set<Int32> {
        Set(runningApplications().lazy.filter { $0.isRegular && candidates.contains($0.processID) }.map(\.processID))
    }
}
