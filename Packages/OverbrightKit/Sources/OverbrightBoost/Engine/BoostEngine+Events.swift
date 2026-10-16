// OverbrightBoost/Engine/BoostEngine+Events.swift — system events, the controllers per online display, and the
// engine's deadlines (pause end, auto-off, schedule boundary). ARCHITECTURE.md §4.1 (shield and safety events reach
// every controller synchronously, then one coalesced re-reduction), §4.3 (event rows), §4.9 (one `TimeSource.sleep`
// per deadline, no repeating timers), §7.1, D9. MainActor.
import CoreGraphics
import Foundation
import OverbrightCore
import OverbrightPolicy

extension BoostEngine {
    // MARK: Events

    /// Every `SystemEvent`: shields and removals act on the controllers before this returns; then one coalesced
    /// re-reduction.
    func handle(_ event: SystemEvent) {
        guard isStarted else { return }
        let all = Array(controllers.values)
        switch event {
        case .locked, .screensaverStarted:
            for controller in all { controller.shield(.shielded) }
        case .willSleep, .screensDidSleep:
            for controller in all { controller.shield(.displayAsleep) }
        case .sessionResigned:
            for controller in all { controller.shield(.notOnConsole) }
        case .displayRemoved(let id):
            removeDisplay(id)
        case .displayConfigurationBegan:
            for controller in all { controller.configurationBegan() }
        case .didWake, .screensDidWake:
            for controller in all { controller.noteResume(.wake) }
        case .unlocked, .screensaverStopped:
            for controller in all { controller.noteResume(.unlock) }
        case .sessionBecameActive:
            for controller in all { controller.noteSessionActive() }
        case .displaysReconfigured:
            syncControllers(reconfigured: true)
        case .colorProfileChanged:
            for controller in all { controller.baseEventOccurred(.colorProfile) }
        case .accessibilityDisplayOptionsChanged:
            for controller in all { controller.baseEventOccurred(.accessibility) }
        case .screenParametersChanged:
            for controller in all { controller.headroomEvent() }
        case .appTerminated(_, let processID):
            continued = continued.filter { $0.value != processID }
            for controller in all { controller.appTerminated(processID: processID) }
        case .hdrSuppressionBegan, .hdrSuppressionEnded, .thermalChanged, .powerChanged, .activeSpaceChanged,
             .appActivated, .appLaunched:
            break
        }
        updateAggregates()
        publish()
        scheduleReduce()
    }

    /// `kCGDisplayRemoveFlag`: its windows are ordered out at once and its controller and ledger entry dropped.
    func removeDisplay(_ id: CGDirectDisplayID) {
        for (key, controller) in controllers where controller.ref.id == id {
            controller.removeNow()
            controllers[key] = nil
            journal.record("display.removed", display: key, time: time)
        }
    }

    /// One controller per online display: new displays get one, gone ones are removed, the rest get new facts (and,
    /// after a reconfiguration pass, re-base and re-place their windows).
    func syncControllers(reconfigured: Bool) {
        lastDirectoryGeneration = displays.generation
        let online = displays.displays
        let keys = Set(online.map(\.ref.key))
        for (key, controller) in controllers where !keys.contains(key) {
            controller.removeNow()
            controllers[key] = nil
        }
        for facts in online {
            if let controller = controllers[facts.ref.key] {
                if reconfigured {
                    controller.reconfigured(facts)
                } else if controller.facts != facts {
                    controller.updateFacts(facts)
                }
            } else {
                controllers[facts.ref.key] = makeController(facts)
            }
        }
    }

    /// A controller wired to the engine's ports, writer, ledger and cache.
    func makeController(_ facts: DisplayFacts) -> DisplayController {
        let controller = DisplayController(
            facts: facts,
            dependencies: DisplayController.Dependencies(
                gamma: gamma, writer: writer, ledger: ledger, headroom: headroom, triggers: triggers,
                conflicts: conflicts, time: time, journal: journal, cache: strategyCache,
                ownEDRSurfaces: ownEDRSurfaces, machine: machine))
        controller.isOffConsole = !signals.snapshot.isSessionActive
        controller.onChange = { [weak self] needsReduction in self?.controllerChanged(needsReduction: needsReduction) }
        return controller
    }

    // MARK: Deadlines (one sleep each, only while on)

    /// Arms or drops the pause deadline and the schedule boundary for the current state (idempotent).
    func refreshDeadlines() {
        let now = time.wallClock
        if let paused = settings[AutomationSettings.pausedUntil], paused <= now {
            settings[AutomationSettings.pausedUntil] = nil
        }
        if isMasterOn, let paused = settings[AutomationSettings.pausedUntil], paused != .distantFuture {
            if armedPauseDeadline != paused { armPause(until: paused) }
        } else if armedPauseDeadline != nil {
            pauseSlot.cancel()
            armedPauseDeadline = nil
        }
        if isMasterOn, let schedule = settings[AutomationSettings.schedule] {
            let boundary = Self.nextBoundary(of: schedule, after: now, calendar: .current)
            if armedScheduleBoundary != boundary { armSchedule(at: boundary) }
        } else if armedScheduleBoundary != nil {
            scheduleSlot.cancel()
            armedScheduleBoundary = nil
        }
    }

    /// The pause ends by itself at `deadline` (one sleep).
    func armPause(until deadline: Date) {
        armedPauseDeadline = deadline
        let wait = Duration.seconds(max(deadline.timeIntervalSince(time.wallClock), 0))
        pauseSlot.run { [weak self] in
            guard let self else { return }
            do { try await self.time.sleep(for: wait) } catch { return }
            self.armedPauseDeadline = nil
            self.settings[AutomationSettings.pausedUntil] = nil
            self.journal.record("pause.ended", display: nil, time: self.time)
            self.reduceNow()
        }
    }

    /// Auto-off: when the master turns on with `autoOffMinutes` set, one sleep until then; the timer then turns the
    /// master off and the HUD says so (`.timerEnded`).
    func armAutoOff() {
        guard let minutes = settings[AutomationSettings.autoOffMinutes], minutes > 0 else { return }
        let wait = Duration.seconds(minutes * 60)
        autoOffAt = time.wallClock.addingTimeInterval(wait.timeInterval)
        autoOffSlot.run { [weak self] in
            guard let self else { return }
            do { try await self.time.sleep(for: wait) } catch { return }
            self.autoOffFired()
        }
    }

    /// The auto-off deadline passed.
    func autoOffFired() {
        guard isMasterOn else { return }
        journal.record("autoOff.fired", display: nil, time: time)
        turnOff()
        emitChange(.timerEnded, source: .automation, display: nil)
        reduceNow()
    }

    /// One sleep until the next schedule boundary, then a re-reduction.
    func armSchedule(at boundary: Date) {
        armedScheduleBoundary = boundary
        let wait = Duration.seconds(max(boundary.timeIntervalSince(time.wallClock), 0))
        scheduleSlot.run { [weak self] in
            guard let self else { return }
            do { try await self.time.sleep(for: wait) } catch { return }
            self.armedScheduleBoundary = nil
            self.reduceNow()
        }
    }

    /// The next start or end of `schedule` after `now` (local time; a boundary exactly now counts as the next day).
    static func nextBoundary(of schedule: ScheduleWindow, after now: Date, calendar: Calendar) -> Date {
        let midnight = calendar.startOfDay(for: now)
        let elapsed = now.timeIntervalSince(midnight)
        let day = 86_400.0
        let waits = [schedule.startMinute, schedule.endMinute].map { minute -> TimeInterval in
            var wait = Double(minute) * 60 - elapsed
            while wait <= 0 { wait += day }
            return wait
        }
        return now.addingTimeInterval(waits.min() ?? day)
    }
}

extension DisplayController {
    /// The begin phase of a reconfiguration: the overlay goes to factor 1 at once (no display queries now).
    func configurationBegan() {
        guard mechanism == .overlay, let overlay else { return }
        try? overlay.setFactor(1, headroomRequest: overlayRequest)
        appliedGain = 1
        appliedFactor = 1
    }
}
