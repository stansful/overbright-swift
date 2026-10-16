// OverbrightSignals/Monitor/SignalsMonitor.swift — the real `SystemSignals`. ARCHITECTURE.md §3.3, §3.6, §4.1,
// §7.1–§7.3, §10.8; D9, D22, D27.
//
// Ported from Cranny's CrannyAppShell/Services/ShellEnvironment.swift (the owner's MIT code) and extended: system sleep
// and wake, screensaver, console state, ColorSync, HDR suppression, thermal state and Low Power Mode through `@Sendable`
// block observers, the power source with synchronous reads, the boost-only battery percent, the full-screen and
// playback check, the OLED idle deadline, the camera rule, the schedule boundary, running conflicts and the Focus
// directive.
//
// Delivery: every handler updates `snapshot` FIRST, then delivers its event to every observer synchronously, in
// registration order, before it returns: a shield event (lock, screensaver, sleep, screens asleep, session resigned) has
// reached the engine, which goes neutral inside its handler, when the notification handler returns (§4.1).
//
// Energy (D22, DESIGN.md §17): while the boost is inactive only event notifications run (`SignalSource.isAlwaysOn`,
// plus the CoreMediaIO listeners while Fill Light's camera rule is on); no timer or IOPS percent source. The
// boost-only sources (battery percent on battery, the OLED idle deadline, the 2 s full-screen re-check, the schedule
// boundary) start in `setBoostActive(true)` and stop in `setBoostActive(false)`, which follows the displays (§7.1:
// active while at least one is scaled or dimmed). One exception keeps that stable: an idle pause in effect keeps its
// 2 s input poll until input returns, because the pause itself turns the boost off (see `applyBoostSources`). Two
// event-driven pieces also run while the boost is inactive, as §7.1's table lists them with the notifications: the
// full-screen re-check 0.6 s after a Space, app or screen event (≈ 3 ms of reads; it is what ends a full-screen or
// per-app pause) and the one re-check when a sticky menu-bar absence expires.
//
// Thread: main. Entry points the system may call on other threads (thermal, Low Power, IOKit callbacks, the
// CoreMediaIO listener proc) are nonisolated and hop through `MainHop` (§8.1 rule 2); each has an off-main test.
import Foundation
import Observation
import OverbrightCore
import os

private let log = Log.logger(.signals)

/// System state and events for the engine, Fill Light and the UI.
@Observable public final class SignalsMonitor: SystemSignals, ServiceLifecycle {
    /// Everything the policy needs from the system.
    public private(set) var snapshot: SystemSnapshot

    @ObservationIgnored let settings: SettingsStore
    @ObservationIgnored let time: any TimeSource
    @ObservationIgnored let journal: any DiagnosticsJournal
    @ObservationIgnored let displays: any DisplayDirectory
    @ObservationIgnored let platform: any SignalsPlatform
    @ObservationIgnored let conflictProbe: RunningAppsConflictProbe?
    @ObservationIgnored let calendar: Calendar
    @ObservationIgnored let focusStore: FocusDirectiveStore
    @ObservationIgnored let fullScreen: FullScreenTracker
    @ObservationIgnored let camera: CameraMonitor
    @ObservationIgnored let idleTimer: DeadlineTimer
    @ObservationIgnored let watchTimer: DeadlineTimer

    @ObservationIgnored private var observers: [(id: UInt64, handler: @MainActor (SystemEvent) -> Void)] = []
    @ObservationIgnored private var lastObserverID: UInt64 = 0
    @ObservationIgnored var notificationTokens: [SignalSource: [ObservationToken]] = [:]
    @ObservationIgnored var sourceTokens: [SignalSource: ObservationToken] = [:]
    @ObservationIgnored var settingsTokens: [ObservationToken] = []
    @ObservationIgnored var scheduleTask: Task<Void, Never>?
    @ObservationIgnored var isIdleTracking = false
    @ObservationIgnored var isWatching = false
    /// `start()` ran and `stop()` did not.
    @ObservationIgnored public private(set) var isStarted = false
    /// The engine's last `setBoostActive(_:)`.
    @ObservationIgnored public private(set) var isBoostActive = false

    /// The live monitor. `conflicts` is the probe the composition root also hands to Boost and the launch rescue
    /// (nil: no conflict detection). Constructing it does no I/O, hardware or network access; `start()` does.
    public convenience init(settings: SettingsStore, time: any TimeSource, journal: any DiagnosticsJournal,
                            displays: any DisplayDirectory, conflicts: RunningAppsConflictProbe?) {
        self.init(settings: settings, time: time, journal: journal, displays: displays, platform: LiveSignalsPlatform(),
                  conflicts: conflicts, calendar: .autoupdatingCurrent)
    }

    /// A monitor over `platform` (tests pass a scripted one and a fixed calendar).
    init(settings: SettingsStore, time: any TimeSource, journal: any DiagnosticsJournal, displays: any DisplayDirectory,
         platform: any SignalsPlatform, conflicts: RunningAppsConflictProbe?, calendar: Calendar) {
        self.settings = settings; self.time = time; self.journal = journal; self.displays = displays
        self.platform = platform; self.conflictProbe = conflicts; self.calendar = calendar
        focusStore = FocusDirectiveStore(settings: settings)
        fullScreen = FullScreenTracker(platform: platform, time: time)
        camera = CameraMonitor(devices: platform.cameras, time: time)
        idleTimer = DeadlineTimer(time: time)
        watchTimer = DeadlineTimer(time: time)
        snapshot = SystemSnapshot(power: PowerState(source: .unknown, batteryPercent: nil, isLowPowerMode: false))
        fullScreen.onOutcome = { [weak self] outcome in self?.apply(outcome) }
        camera.onChange = { [weak self] inUse in self?.update { $0.isCameraInUse = inUse } }
    }

    /// The sources running now (the energy acceptance test enumerates them in every state).
    public var activeSources: Set<SignalSource> {
        var sources = Set(notificationTokens.filter { !$0.value.isEmpty }.keys)
        sources.formUnion(sourceTokens.keys)
        if camera.isRunning { sources.insert(.camera) }
        if isIdleTracking { sources.insert(.idleDeadline) }
        if isWatching { sources.insert(.fullScreenWatch) }
        if scheduleTask != nil { sources.insert(.scheduleBoundary) }
        return sources
    }

    // MARK: SystemSignals

    /// Registers `handler` until the token is cancelled or released; events arrive synchronously, in registration
    /// order.
    public func addEventObserver(_ handler: @escaping @MainActor (SystemEvent) -> Void) -> ObservationToken {
        lastObserverID += 1
        let id = lastObserverID
        observers.append((id, handler))
        return ObservationToken { [weak self] in self?.observers.removeAll { $0.id == id } }
    }

    /// Delivers `event` to every observer before returning. Signals' own handlers call it after updating the
    /// snapshot; the composition root forwards Displays' events through it (`displayConfigurationBegan`,
    /// `displayRemoved`, `displaysReconfigured`, `screenParametersChanged`), so every event reaches the engine the
    /// same way.
    public func post(_ event: SystemEvent) {
        for observer in observers { observer.handler(event) }
    }

    /// Starts or stops the boost-only sources. `true` first reads the power source and battery percent synchronously
    /// (no event: the caller reduces right after).
    public func setBoostActive(_ active: Bool) {
        if active != isBoostActive { record("signals.boostActive", ["active": active ? 1 : 0]) }
        isBoostActive = active
        if active { refreshPowerNow() }
        applyBoostSources()
        if active, isStarted { fullScreen.request() }
    }

    /// Synchronous `IOPSCopyPowerSourcesInfo` read into `snapshot.power` (no event: the caller reduces right after).
    public func refreshPowerNow() {
        let power = platform.readPower()
        update { $0.power = power }
        applyBoostSources()
    }

    /// Persists the Focus filter's directive and publishes it.
    public func setFocusDirective(_ directive: FocusDirective) {
        focusStore.directive = directive
        update { $0.focus = directive }
    }

    // MARK: ServiceLifecycle

    /// "signals".
    public var serviceName: String { "signals" }

    /// Reads the launch state and registers the always-on sources.
    public func start() async { startNow() }

    /// Stops every source.
    public func stop() async { stopNow() }

    /// Stops every source at once.
    public func stopNow() {
        guard isStarted else { return }
        isStarted = false
        for token in notificationTokens.values.joined() { token.cancel() }
        notificationTokens = [:]
        for token in sourceTokens.values { token.cancel() }
        sourceTokens = [:]
        for token in settingsTokens { token.cancel() }
        settingsTokens = []
        fullScreen.stop()
        camera.stop()
        applyBoostSources()
        record("signals.stopped")
    }

    /// The synchronous body of `start()`.
    func startNow() {
        guard !isStarted else { return }
        isStarted = true
        let session = platform.sessionState()
        update { snapshot in
            snapshot.power = platform.readPower()
            snapshot.thermal = platform.thermalLevel()
            snapshot.isScreenLocked = session.isScreenLocked
            snapshot.isSessionActive = session.isOnConsole
            snapshot.reduceMotion = platform.reduceMotion()
            snapshot.isHDRSuppressed = platform.isHDRSuppressed()
            snapshot.conflicts = conflictProbe?.runningConflicts() ?? []
            snapshot.focus = focusStore.directive
        }
        registerNotifications()
        if let token = platform.observePowerSourceSwitches({ [weak self] in self?.powerSourceChanged() }) {
            sourceTokens[.powerSourceSwitch] = token
        }
        observeSettings()
        fullScreen.start()
        fullScreen.request()
        updateCamera()
        applyBoostSources()
        record("signals.started", ["onConsole": session.isOnConsole ? 1 : 0, "locked": session.isScreenLocked ? 1 : 0])
        let console = session.isOnConsole, locked = session.isScreenLocked
        log.info("signals started: console \(console, privacy: .public), locked \(locked, privacy: .public)")
    }

    // MARK: Snapshot

    /// Applies `change` to the snapshot, publishing only a real change (one observation per change).
    func update(_ change: (inout SystemSnapshot) -> Void) {
        var next = snapshot
        change(&next)
        if next != snapshot { snapshot = next }
    }

    /// Publishes one full-screen check.
    func apply(_ outcome: FullScreenTracker.Outcome) {
        update { snapshot in
            snapshot.fullScreenDisplays = outcome.fullScreenDisplays
            snapshot.fullScreenVideoDisplays = outcome.fullScreenVideoDisplays
            snapshot.frontmost = outcome.frontmost
        }
    }

    /// Records a journal line (codes and numbers only).
    func record(_ code: String, _ values: [String: Double] = [:]) {
        journal.record(JournalEvent(seconds: time.now.sinceOrigin.timeInterval, category: LogCategory.signals.rawValue,
                                    display: nil, code: code, values: values))
    }
}
