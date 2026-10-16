// OverbrightSignals/Monitor/SignalsMonitor+BoostSources.swift — the sources that run only while the boost is active,
// and the settings that shape them. ARCHITECTURE.md §6.5, §7.1 (boost-only rows), §7.3, D10, D22.
// - battery percent: IOKit's every-change source, only on battery (the source switch itself is always on);
// - OLED idle: one deadline (`IdleScheduler`), only when an OLED display is online; once idle, the 2 s input poll runs
//   until input returns even after the boost went inactive (the idle pause itself makes every OLED neutral; stopping
//   the poll then would clear the flag, re-boost and pause again every few seconds while the user is away);
// - full-screen watch: the 2 s re-check while a full-screen or "while playing" rule is on (borderless games, players
//   starting or stopping without a Space change). While the boost is inactive only events re-check (Space, app,
//   screen, wake), so a pause that made every display neutral and whose player then stops without any such event
//   lasts until the next one: keeping the watch then would mean a 2 s timer with the master off (§17);
// - schedule boundary: one sleep towards the next boundary (`ScheduleTimer`), only while a schedule is set.
// `applyBoostSources()` reconciles all four with the state; it runs on every change that could matter.
// Thread: main.
import Foundation
import OverbrightCore

extension SignalsMonitor {
    /// The full-screen and playback re-check interval while boosted (the drift check's cadence, DESIGN.md §17).
    static let watchInterval: Duration = .seconds(2)

    /// Starts or stops each boost-only source to match the state.
    func applyBoostSources() {
        let boosting = isStarted && isBoostActive
        setBatteryPercent(boosting && snapshot.power.source == .battery)
        setIdleTracking(isStarted && anyOLED && (isBoostActive || snapshot.isIdleBeyondThreshold))
        setWatching(boosting && watchRuleIsOn)
        setSchedule(boosting && settings[AutomationSettings.schedule] != nil)
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
    /// the OLED went away or Signals stopped: the pause ends with the source.
    private func setIdleTracking(_ on: Bool) {
        if on, !isIdleTracking {
            isIdleTracking = true
            evaluateIdle()
        } else if !on, isIdleTracking {
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

    /// Sleeps towards the next boundary in chunks; posts `scheduleBoundary` when the wall clock crossed one.
    private func runSchedule() async {
        var last = time.wallClock
        while !Task.isCancelled {
            guard let window = settings[AutomationSettings.schedule],
                  let next = ScheduleTimer.nextBoundary(after: last, window: window, calendar: calendar) else { return }
            do { try await time.sleep(for: ScheduleTimer.sleepDuration(until: next, now: time.wallClock)) } catch { return }
            let now = time.wallClock
            if ScheduleTimer.crossedBoundary(from: last, to: now, window: window, calendar: calendar) {
                record("signals.scheduleBoundary")
                post(.scheduleBoundary)
            }
            last = now
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
