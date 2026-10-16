// OverbrightSignalsTests/Fakes/FakeSignalsPlatform.swift — a scripted `SignalsPlatform`. ARCHITECTURE.md §9.1 (Signals:
// pure functions with fixtures; no test observes the real workspace, IOKit or CoreMediaIO).
// Private notification centers stand in for the workspace, distributed and default centers, so posting a notification
// here exercises the monitor's real registration code. Reads return scripted values and are counted; the IOKit sources
// record whether they are registered.
import Foundation
import OverbrightCore
@testable import OverbrightSignals

@MainActor final class FakeSignalsPlatform: SignalsPlatform {
    /// The userInfo key under which `post(_:in:app:)` carries a `RunningAppInfo`.
    nonisolated static let appKey = "app"

    let workspaceCenter = NotificationCenter()
    let distributedCenter = NotificationCenter()
    let localCenter = NotificationCenter()
    var ownProcessID: Int32 = 100
    let cameraDevices = FakeCameraDevices()
    var cameras: any CameraDevices { cameraDevices }

    var session = SessionState(isOnConsole: true, isScreenLocked: false)
    var power = PowerState(source: .adapter, batteryPercent: 100, isLowPowerMode: false)
    var thermal: ThermalLevel = .nominal
    var reduceMotionValue = false
    var hdrSuppressed = false
    var frontmost: RunningAppInfo?
    var running: [RunningAppInfo] = []
    var dockPID: Int32? = 50
    var screenList: [FullScreenDetector.Display] = []
    var windows = WindowListSnapshot(windows: [], windowServerPID: nil)
    /// When set, `windowList` builds its snapshot from these raw entries the way the live read does, with
    /// `locatedWindowServer` as the libproc scan's answer and `windowServerPaths` as each PID's executable.
    var rawWindowList: [NSDictionary]?
    var locatedWindowServer: Int32?
    var windowServerPaths: [Int32: String] = [:]
    var holders: Set<Int32>? = []
    var idleSeconds: Double? = 0
    var categories: [URL: String] = [:]
    /// "Displays have separate Spaces" (the default on).
    var separateSpaces = true

    private(set) var powerReads = 0
    private(set) var windowReads = 0
    /// The `windowServerPID` each window read was given.
    private(set) var windowServerHints: [Int32?] = []
    /// libproc scans for the WindowServer (raw mode only).
    private(set) var windowServerScans = 0
    private(set) var idleReads = 0
    private(set) var switchSources = 0
    private(set) var batterySources = 0
    /// Running-list observations registered and not yet cancelled.
    private(set) var runningListObservers = 0
    private var switchHandler: (@MainActor @Sendable () -> Void)?
    private var batteryHandler: (@MainActor @Sendable () -> Void)?
    private var runningListHandler: (@MainActor @Sendable (RunningAppsChange) -> Void)?

    func sessionState() -> SessionState { session }
    func readPower() -> PowerState { powerReads += 1; return power }
    func thermalLevel() -> ThermalLevel { thermal }
    func reduceMotion() -> Bool { reduceMotionValue }
    func isHDRSuppressed() -> Bool { hdrSuppressed }
    func frontmostApplication() -> RunningAppInfo? { frontmost }
    func runningApplications() -> [RunningAppInfo] { running }
    func observeRunningApplications(_ handler: @escaping @MainActor @Sendable (RunningAppsChange) -> Void)
        -> ObservationToken {
        runningListObservers += 1
        runningListHandler = handler
        return ObservationToken { [weak self] in self?.runningListObservers -= 1; self?.runningListHandler = nil }
    }
    nonisolated func application(in notification: Notification) -> RunningAppInfo? {
        notification.userInfo?[Self.appKey] as? RunningAppInfo
    }
    func dockProcessID() -> Int32? { dockPID }
    func screens() -> [FullScreenDetector.Display] { screenList }
    func screensHaveSeparateSpaces() -> Bool { separateSpaces }
    func windowList(windowServerPID: Int32?) async -> WindowListSnapshot {
        windowReads += 1
        windowServerHints.append(windowServerPID)
        guard let rawWindowList else { return windows }
        let paths = windowServerPaths
        return WindowListSnapshot.make(rawWindowList, windowServerPID: windowServerPID,
                                       isWindowServer: { paths[$0].map(WindowServerProcess.isWindowServerPath) ?? false },
                                       locate: { windowServerScans += 1; return locatedWindowServer })
    }
    func displaySleepHolders() -> Set<Int32>? { holders }
    func secondsSinceLastInput() -> Double? { idleReads += 1; return idleSeconds }
    func appCategory(bundleURL: URL) -> String? { categories[bundleURL] }

    /// Distributed registrations on the private `distributedCenter` (the live one adds immediate delivery).
    func observeDistributed(_ name: Notification.Name, _ handler: @escaping @MainActor @Sendable () -> Void)
        -> ObservationToken {
        let center = distributedCenter
        let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { handler() }
        }
        return ObservationToken { center.removeObserver(token) }
    }

    func observePowerSourceSwitches(_ handler: @escaping @MainActor @Sendable () -> Void) -> ObservationToken? {
        switchSources += 1
        switchHandler = handler
        return ObservationToken { [weak self] in self?.switchSources -= 1; self?.switchHandler = nil }
    }

    func observeBatteryChanges(_ handler: @escaping @MainActor @Sendable () -> Void) -> ObservationToken? {
        batterySources += 1
        batteryHandler = handler
        return ObservationToken { [weak self] in self?.batterySources -= 1; self?.batteryHandler = nil }
    }

    // MARK: Scripting

    /// Posts `name` on `center` (from the main thread), carrying `app` like a workspace notification.
    func post(_ name: Notification.Name, in center: NotificationCenter, app: RunningAppInfo? = nil) {
        center.post(name: name, object: nil, userInfo: app.map { [Self.appKey: $0] })
    }

    /// The running list changes the way AppKit's KVO reports it (`running` is updated first, as the live list is when
    /// the observer runs): `added` join, `removed` leave.
    func changeRunningList(added: [RunningAppInfo] = [], removed: [RunningAppInfo] = []) {
        let gone = Set(removed.map(\.processID))
        running = running.filter { !gone.contains($0.processID) } + added
        runningListHandler?(RunningAppsChange(added: added, removed: removed))
    }

    /// IOKit's source-switch callback fires with `power` as the new state.
    func switchPowerSource(to power: PowerState) {
        self.power = power
        switchHandler?()
    }

    /// IOKit's every-change callback fires with `power` as the new state (a percent update).
    func changeBattery(to power: PowerState) {
        self.power = power
        batteryHandler?()
    }
}
