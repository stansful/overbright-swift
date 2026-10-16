// OverbrightSignals/Monitor/LiveSignalsPlatform.swift — the real `SignalsPlatform`. ARCHITECTURE.md §7.1, §7.3.
// Every read is public and permission-free: the session dictionary, IOKit power sources, `ProcessInfo`, `NSWorkspace`,
// `NSScreen` (and its separate-Spaces preference), the running list's KVO, the window list (bounds, layers, PIDs, alpha
// only), power assertions, the idle timestamp (`CGEventSource.secondsSinceLastEventType`, no Input Monitoring) and
// Info.plist categories. Nothing here writes, and constructing it touches nothing
// (`constructingServicesTouchesNoHardware`).
// Thread: main, except `windowList(windowServerPID:)`, whose read runs off the main actor.
import AppKit
import CoreGraphics
import Foundation
import OverbrightCore

/// The system.
final class LiveSignalsPlatform: SignalsPlatform {
    /// The Dock, kept between checks (it changes only when the Dock restarts).
    private var dock: NSRunningApplication?
    private var cameraDevices: CoreMediaIOCameras?

    /// Touches nothing.
    init() {}

    /// `NSWorkspace.shared.notificationCenter`.
    var workspaceCenter: NotificationCenter { NSWorkspace.shared.notificationCenter }
    /// `NotificationCenter.default`.
    var localCenter: NotificationCenter { NotificationCenter.default }
    /// This process.
    var ownProcessID: Int32 { ProcessInfo.processInfo.processIdentifier }
    /// CoreMediaIO, created on first use.
    var cameras: any CameraDevices {
        if let cameraDevices { return cameraDevices }
        let devices = CoreMediaIOCameras()
        cameraDevices = devices
        return devices
    }

    /// `kCGSessionOnConsoleKey` and `CGSSessionScreenIsLocked` (an unreadable dictionary counts as on the console and
    /// unlocked: the lock and session notifications correct it).
    func sessionState() -> SessionState {
        let session = CGSessionCopyCurrentDictionary() as? [String: Any] ?? [:]
        return SessionState(isOnConsole: session[kCGSessionOnConsoleKey] as? Bool ?? true,
                            isScreenLocked: session["CGSSessionScreenIsLocked"] as? Bool ?? false)
    }

    /// IOKit power sources and Low Power Mode.
    func readPower() -> PowerState {
        PowerSourceReader.read(isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled)
    }

    /// `ProcessInfo.thermalState`.
    func thermalLevel() -> ThermalLevel { ThermalLevel(ProcessInfo.processInfo.thermalState) }

    /// `NSWorkspace.accessibilityDisplayShouldReduceMotion`.
    func reduceMotion() -> Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// macOS 26+: the application's current HDR-suppression request.
    func isHDRSuppressed() -> Bool {
        if #available(macOS 26.0, *) { return NSApp?.applicationShouldSuppressHighDynamicRangeContent ?? false }
        return false
    }

    /// `NSWorkspace.frontmostApplication`.
    func frontmostApplication() -> RunningAppInfo? { NSWorkspace.shared.frontmostApplication.map(RunningAppInfo.init) }

    /// `NSWorkspace.runningApplications`.
    func runningApplications() -> [RunningAppInfo] { NSWorkspace.shared.runningApplications.map(RunningAppInfo.init) }

    /// KVO on `NSWorkspace.shared.runningApplications` (AppKit updates it on the main run loop).
    func observeRunningApplications(_ handler: @escaping @MainActor @Sendable (RunningAppsChange) -> Void)
        -> ObservationToken {
        RunningAppsObserver.observe(NSWorkspace.shared, \.runningApplications, handler)
    }

    /// `NSWorkspace.applicationUserInfoKey` of a workspace notification (`NSRunningApplication` is thread-safe).
    nonisolated func application(in notification: Notification) -> RunningAppInfo? {
        (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication).map(RunningAppInfo.init)
    }

    /// The Dock's PID, looked up again only after it quit.
    func dockProcessID() -> Int32? {
        if let dock, !dock.isTerminated { return dock.processIdentifier }
        dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
        return dock?.processIdentifier
    }

    /// `NSScreen.screens` with `CGDisplayBounds` and the notch band (`safeAreaInsets.top`).
    func screens() -> [FullScreenDetector.Display] {
        NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            let id = CGDirectDisplayID(number.uint32Value)
            guard let key = DisplayKey.of(id) else { return nil }
            return FullScreenDetector.Display(key: key, bounds: CGDisplayBounds(id), notchBand: screen.safeAreaInsets.top)
        }
    }

    /// `NSScreen.screensHaveSeparateSpaces` (a login-session preference; cheap to read).
    func screensHaveSeparateSpaces() -> Bool { NSScreen.screensHaveSeparateSpaces }

    /// The window list, read off the main actor.
    func windowList(windowServerPID: Int32?) async -> WindowListSnapshot {
        await WindowListSnapshot.read(windowServerPID: windowServerPID)
    }

    /// `IOPMCopyAssertionsByProcess`.
    func displaySleepHolders() -> Set<Int32>? { PlaybackAssertions.read() }

    /// Idle time of the session (any input event; `kCGAnyInputEventType` is `~0`, built without a force unwrap).
    func secondsSinceLastInput() -> Double? {
        guard let anyInput = CGEventType(rawValue: ~0) else { return nil }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }

    /// The bundle's Info.plist category.
    func appCategory(bundleURL: URL) -> String? { GameCategory.category(ofBundleAt: bundleURL) }

    /// `DistributedNotificationCenter.default()` with `.deliverImmediately` (an agent app is rarely active).
    func observeDistributed(_ name: Notification.Name, _ handler: @escaping @MainActor @Sendable () -> Void)
        -> ObservationToken {
        DistributedObserver.observe(name, handler)
    }

    /// IOKit's limited power notification.
    func observePowerSourceSwitches(_ handler: @escaping @MainActor @Sendable () -> Void) -> ObservationToken? {
        PowerSourceNotifications.observeSourceSwitches(handler)
    }

    /// IOKit's every-change power notification.
    func observeBatteryChanges(_ handler: @escaping @MainActor @Sendable () -> Void) -> ObservationToken? {
        PowerSourceNotifications.observeEveryChange(handler)
    }
}
