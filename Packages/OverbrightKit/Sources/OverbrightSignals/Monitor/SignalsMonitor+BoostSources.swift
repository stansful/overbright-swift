// OverbrightSignals/Monitor/SignalsMonitor+BoostSources.swift — the sources that run only while the boost is active,
// and the settings that shape them. ARCHITECTURE.md §6.5, §7.1 (boost-only rows), §7.3, D10, D22.
// - battery percent: IOKit's every-change source, only on battery (the source switch itself is always on);
// - OLED idle: one deadline (`IdleScheduler`), only when an OLED display is online; once idle, the 2 s input poll runs
//   until input returns even after the boost went inactive (the idle pause itself makes every OLED neutral; stopping
//   the poll then would clear the flag, re-boost and pause again every few seconds while the user is away), except
//   while shielded;
// - full-screen watch: the 2 s re-check while a full-screen or "while playing" rule is on (borderless games, players
//   starting or stopping without a Space change). While the boost is inactive only events re-check (Space, app,
//   screen, wake), so a pause that made every display neutral and whose player then stops without any such event
//   lasts until the next one: keeping the watch then would mean a 2 s timer with the master off (§17). The watch is
//   Signals' own timer, not a ride on the engine's drift check (WP14 decision, §7.1 "Playing video"): the drift check
//   runs per display inside Boost, the full-screen state is one system-wide read here, and the two 2 s sleeps carry
//   the time source's 10 % tolerance, so the system may coalesce them;
// - schedule boundary: one sleep towards the next boundary (`ScheduleTimer`), only while a schedule is set.
// While shielded (locked, screensaver, displays or system asleep, off the console) the first three stop, the OLED idle
// poll too: nobody sees the screen, and the engine holds every display neutral. An idle pause keeps its flag until the
// shield lifts; the schedule's one sleep stays (it wakes only at a boundary).
// `applyBoostSources()` reconciles all four with the state; it runs on every change that could matter.
// Thread: main.
import Foundation
import OverbrightCore

extension SignalsMonitor {
    /// The full-screen and playback re-check interval while boosted (the drift check's cadence, its own timer,
    /// DESIGN.md §17).
    static let watchInterval: Duration = .seconds(2)

    /// Starts or stops each boost-only source to match the state. While the screen cannot be seen
    /// (`SystemSnapshot.isShielded`: locked, screensaver, displays or system asleep, another session on the console)
    /// the battery percent, the idle deadline and the full-screen watch stop; an idle pause keeps its flag until the
    /// shield lifts and the idle time is read again (`shieldChanged`).
    func applyBoostSources() {
        let boosting = isStarted && isBoostActive
        let visible = !snapshot.isShielded
        setBatteryPercent(boosting && visible && snapshot.power.source == .battery)
        setIdleTracking(isStarted && anyOLED && (isBoostActive || snapshot.isIdleBeyondThreshold), suspended: !visible)
        setWatching(boosting && visible && watchRuleIsOn)
        setSchedule(boosting && settings[AutomationSettings.schedule] != nil)
    }

    /// A shield began or ended (lock, screensaver, display or system sleep, console): the boost-only sources follow.
    /// When the last shield lifts while boosting, the power is read first (the battery percent source stopped
    /// meanwhile; `powerChanged` follows the shield's own event when it changed); idle tracking restarts with a fresh
    /// read of the idle time.
    func shieldChanged() {
        if !snapshot.isShielded, isBoostActive {
            powerSourceChanged()                                  // re-applies the sources too
        } else {
            applyBoostSources()
        }
    }

    /// A rule that needs the periodic re-check is on.
    var watchRuleIsOn: Bool {
        if settings[AutomationSettings.pauseForFullScreenVideo] || settings[AutomationSettings.pauseForAllFullScreen] {
            return true
        }
        return settings[AutomationSettings.pauseForListedApps]
            && settings[AutomationSettings.pausedApps].contains { $0.isEnabled && $0.mode == .whilePlaying }
    }

    // MARK: Battery percent

    private func setBatteryPercent(_ on: Bool) {
        if on, sourceTokens[.batteryPercent] == nil {
            sourceTokens[.batteryPercent] = platform.observeBatteryChanges { [weak self] in self?.powerSourceChanged() }
        } else if !on, let token = sourceTokens.removeValue(forKey: .batteryPercent) {
            token.cancel()
        }
    }

    // MARK: OLED idle

    /// `on`: started, an OLED online, and the boost active or an idle pause in effect. Off with the flag still set means
    /// the OLED went away or Signals stopped: the pause ends with the source. `suspended` (shielded): no deadline runs,
    /// the flag stays as it is, and the next unsuspended call reads the idle time again.
    private func setIdleTracking(_ on: Bool, suspended: Bool) {
        let runs = on && !suspended
        if runs, !isIdleTracking {
            isIdleTracking = true
            evaluateIdle()
        } else if !runs, isIdleTracking {
            isIdleTracking = false
            idleTimer.cancel()
        }
        if !on, snapshot.isIdleBeyondThreshold {
            record("signals.idle", ["idle": 0])
            update { $0.isIdleBeyondThreshold = false }
        }
    }

    /// Reads the idle time, publishes the decision and sets the one next deadline. When input returns while the boost
    /// is inactive (the idle pause held every display neutral), the source stops: the engine re-reduces on the cleared
    /// flag, and its `setBoostActive(true)` starts the source again with a fresh deadline.
    func evaluateIdle() {
        guard isIdleTracking else { return }
        let threshold = IdleScheduler.threshold(minutes: settings[AutomationSettings.oledIdleMinutes])
        let heldAwake = !(platform.displaySleepHolders() ?? []).isEmpty
        let decision = IdleScheduler.evaluate(secondsSinceInput: platform.secondsSinceLastInput(), threshold: threshold,
                                              displayHeldAwake: heldAwake)
        if decision.isIdle != snapshot.isIdleBeyondThreshold { record("signals.idle", ["idle": decision.isIdle ? 1 : 0]) }
        update { $0.isIdleBeyondThreshold = decision.isIdle }
        guard isIdleTracking else { return }                     // an observer stopped Signals meanwhile
        guard isBoostActive || decision.isIdle else {
            isIdleTracking = false
            idleTimer.cancel()
            return
        }
        idleTimer.schedule(after: decision.nextCheck) { [weak self] in self?.evaluateIdle() }
    }

    // MARK: Full-screen watch

    private func setWatching(_ on: Bool) {
        if on, !isWatching {
            isWatching = true
            scheduleWatchTick()
        } else if !on, isWatching {
            isWatching = false
            watchTimer.cancel()
        }
    }

    private func scheduleWatchTick() {
        watchTimer.schedule(after: Self.watchInterval) { [weak self] in
            guard let self, self.isWatching else { return }
            self.scheduleWatchTick()
            Task { await self.fullScreen.check() }
        }
    }

    // MARK: Schedule boundary

    private func setSchedule(_ on: Bool) {
        if on, scheduleTask == nil {
            scheduleTask = Task { [weak self] in await self?.runSchedule() }
        } else if !on, let task = scheduleTask {
            task.cancel()
            scheduleTask = nil
        }
    }

    /// The schedule changed: start over from the new window.
    func restartSchedule() {
        scheduleTask?.cancel()
        scheduleTask = nil
        applyBoostSources()
    }

    /// Sleeps towards the next boundary in chunks; posts `scheduleBoundary` when the wall clock crossed one or the
    /// window's inside/outside state changed without a crossing (a clock step back, a time-zone change). `last` never
    /// moves past a boundary that was not posted: without a crossing, `now` is still before it. A schedule change
    /// restarts the run (`restartSchedule`).
    private func runSchedule() async {
        guard let window = settings[AutomationSettings.schedule] else { return }
        var last = time.wallClock
        var wasInside = ScheduleTimer.isInside(last, window: window, calendar: calendar)
        while !Task.isCancelled {
            guard let next = ScheduleTimer.nextBoundary(after: last, window: window, calendar: calendar) else { return }
            do { try await time.sleep(for: ScheduleTimer.sleepDuration(until: next, now: time.wallClock)) } catch { return }
            let now = time.wallClock
            if ScheduleTimer.shouldPost(last: last, wasInside: wasInside, now: now, window: window, calendar: calendar) {
                record("signals.scheduleBoundary")
                post(.scheduleBoundary)
            }
            last = now
            wasInside = ScheduleTimer.isInside(now, window: window, calendar: calendar)
        }
    }

    // MARK: Settings and displays

    /// Follows the settings and displays that shape the sources.
    func observeSettings() {
        settingsTokens = [
            observe({ [settings] in settings[FillLightSettings.autoWithCamera] }) { [weak self] _ in self?.updateCamera() },
            observe({ [settings] in settings[FillLightSettings.cameraFilter] }) { [weak self] filter in
                self?.camera.setFilter(filter)
            },
            observe({ [weak self] in self?.watchRuleIsOn ?? false }) { [weak self] _ in self?.applyBoostSources() },
            observe({ [settings] in settings[AutomationSettings.schedule] }) { [weak self] _ in self?.restartSchedule() },
            observe({ [settings] in settings[AutomationSettings.oledIdleMinutes] }) { [weak self] _ in
                self?.evaluateIdle()
            },
            observe({ [weak self] in self?.anyOLED ?? false }) { [weak self] _ in self?.applyBoostSources() },
        ]
    }

    /// An OLED display is online (after the per-display override).
    var anyOLED: Bool {
        OLEDPresence.anyOLED(displays.displays, preferences: settings[DisplaySettings.perDisplay])
    }

    /// Starts or stops the camera monitor with Fill Light's camera rule.
    func updateCamera() {
        let on = isStarted && settings[FillLightSettings.autoWithCamera]
        if on, !camera.isRunning {
            camera.start(filter: settings[FillLightSettings.cameraFilter])
        } else if !on, camera.isRunning {
            camera.stop()
        }
    }
}
