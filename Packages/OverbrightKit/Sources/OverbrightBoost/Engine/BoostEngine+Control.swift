// OverbrightBoost/Engine/BoostEngine+Control.swift — the `BoostControl` requests: master, levels (linked or per
// display), extra brightness, dimming and Dim All, steps in stops, Back to Standard, pause and resume, Continue Anyway
// and Try Again (the low-level confirmation lives in `+LowLevel`). ARCHITECTURE.md §3.6, §4.9, §5.3, §5.9, §7.2;
// DESIGN.md §5.5. MainActor.
import Foundation
import OverbrightCore
import OverbrightPolicy

extension BoostEngine {
    // MARK: Master

    /// On reads the power source synchronously first (so the reducer never sees a stale battery percentage); off
    /// disarms every display (ramp, baseline, triggers removed); stored levels stay.
    public func setOn(_ on: Bool, source: ControlSource) {
        if on {
            if isMasterOn {
                refreshPowerBeforeABoost()
            } else {
                turnOn(source: source)
                askToKeepAfterTurningOn(source: source)
            }
        } else {
            turnOff()
        }
        reduceNow(ControlRequest(source: source, kind: on ? .turnOn : .turnOff, display: nil, wantsBoost: on))
    }

    /// A request for the boost half while the master is already on: when no display keeps the boost-only sources
    /// running, the battery percentage is as old as the last boost, so it is read synchronously before reducing (§7.1,
    /// D9; one read). Turning on reads it itself (`turnOn`).
    func refreshPowerBeforeABoost() {
        guard !boostSourcesActive else { return }
        signals.refreshPowerNow()
    }

    /// Turns the master on or off.
    public func toggle(source: ControlSource) { setOn(!isMasterOn, source: source) }

    /// Master on (a no-op while the self-test or calibration holds it off): the power read, the auto-off deadline.
    func turnOn(source: ControlSource) {
        guard !isMasterOn else { return }
        guard !instrumentHold, calibrationSession == nil else {
            journal.record("master.heldOff", display: nil, time: time)
            return
        }
        signals.refreshPowerNow()
        isMasterOn = true
        journal.record("master.on", display: nil, time: time)
        armAutoOff()
    }

    /// Master off: every deadline goes (zero work while off); an unanswered "Keep this level?" reverts. The levels
    /// still owed reach UserDefaults first, unless `persisting` is false: quit's synchronous `stopNow()` writes the
    /// baselines before that settings write (a JSON encode and a cfprefsd message) and the levels after them
    /// (`finishStop`).
    func turnOff(persisting: Bool = true) {
        if persisting { persistLevels() }
        if pendingLowLevel != nil { restoreLowLevel() }
        guard isMasterOn else { return }
        isMasterOn = false
        journal.record("master.off", display: nil, time: time)
        autoOffSlot.cancel(); autoOffAt = nil
        pauseSlot.cancel(); armedPauseDeadline = nil
        scheduleSlot.cancel(); armedScheduleBoundary = nil
        preparingSlot.cancel()
    }

    // MARK: Levels

    /// Stores `level` (linked, or for one display or all), turns the master on and ends a user pause (direct
    /// manipulation is intent; a guard is not lifted), asks "Keep this level?" when it gets very dark.
    public func setLevel(_ level: LevelPosition, for display: DisplayKey?, source: ControlSource) {
        let keys = display.map { [$0] } ?? displays.displays.map(\.ref.key)
        applyLevels(Self.byKey(keys.map { ($0, level) }), source: source, display: display)
    }

    /// A preset's position, or a multiplier mapped through each display's own top (§4.9).
    public func setExtraBrightness(_ request: ExtraBrightnessRequest, for display: DisplayKey?,
                                   source: ControlSource) {
        switch request {
        case .preset(let preset):
            setLevel(preset.position, for: display, source: source)
        case .multiplier(let gain):
            if settings[DisplaySettings.linkLevels] {
                // One linked level: the multiplier is read on the named display, else the first (built-in) one.
                guard let key = display ?? displays.displays.first?.ref.key else { return }
                setLevel(LevelMapping.position(forGain: gain, top: top(for: key)), for: nil, source: source)
                return
            }
            let keys = display.map { [$0] } ?? displays.displays.map(\.ref.key)
            let levels = keys.map { ($0, LevelMapping.position(forGain: gain, top: top(for: $0))) }
            applyLevels(Self.byKey(levels), source: source, display: display)
        }
    }

    /// Dims one display, or every display that can dim, to `light` (0.02…0.99 of Standard light); it becomes the
    /// light of Dim All.
    public func setDimLight(_ light: Double, for display: DisplayKey?, source: ControlSource) {
        let clamped = min(max(light.isFinite ? light : 0.25, LevelMapping.minimumDimLight), 0.99)
        settings[DisplaySettings.lastDimLight] = clamped
        let position = LevelMapping.position(forDimLight: clamped)
        let keys = display.map { [$0] } ?? dimmableKeys()
        applyLevels(Self.byKey(keys.map { ($0, position) }), source: source, display: display)
    }

    /// Brighter / Less Bright: one step in stops (`shortcuts.stepSize`) from the level of the display under the
    /// pointer (or the linked level); a step never crosses Standard in one press; turns the master on. While off it
    /// steps from Standard, so Less Bright never brightens.
    public func step(_ direction: StepDirection, source: ControlSource) {
        guard let key = pointerDisplay(displays.displays) ?? displays.displays.first?.ref.key else { return }
        let stops = settings[ShortcutSettings.stepSize].stops * (direction == .brighter ? 1 : -1)
        let from = isMasterOn ? storedLevel(of: key) : .standard
        let next = StepMath.step(from: from, by: stops, top: top(for: key))
        setLevel(next, for: settings[DisplaySettings.linkLevels] ? nil : key, source: source)
    }

    /// Dim All Displays ⇄ Stop Dimming: if any display that can dim is not dimmed, every one goes to `lastDimLight`
    /// (their levels remembered in memory); otherwise every one returns to its remembered level (or Standard).
    public func toggleDim(source: ControlSource) {
        let keys = dimmableKeys()
        guard !keys.isEmpty else { return }
        let linked = settings[DisplaySettings.linkLevels]
        let anyUndimmed = !isMasterOn || keys.contains { !storedLevel(of: $0).isDim }
        if anyUndimmed {
            if linked { linkedDimMemory = settings[DisplaySettings.linkedLevel] }
            for key in keys { dimMemory[key] = storedLevel(of: key) }
            let position = LevelMapping.position(forDimLight: settings[DisplaySettings.lastDimLight])
            applyLevels(Self.byKey(keys.map { ($0, position) }), source: source, display: nil)
        } else {
            var levels: [DisplayKey: LevelPosition] = [:]
            for key in keys { levels[key] = linked ? (linkedDimMemory ?? .standard) : (dimMemory[key] ?? .standard) }
            dimMemory = [:]
            linkedDimMemory = nil
            applyLevels(levels, source: source, display: nil)
        }
    }

    /// Back to Standard: master off within a 120 ms ramp, dims undone, stored levels kept; never depends on the
    /// panel, the policy or a fresh reading.
    public func returnToStandard(source: ControlSource) {
        turnOff()
        for controller in controllers.values { controller.rampBackToStandard() }
        reduceNow(ControlRequest(source: source, kind: .backToStandard, display: nil, wantsBoost: false))
    }

    // MARK: Pause, conflicts, trips

    /// The engine owns the pause deadline (`automations.pausedUntil`) and its single sleep; nil pauses until resumed.
    public func pause(until deadline: Date?, source: ControlSource) {
        settings[AutomationSettings.pausedUntil] = deadline ?? .distantFuture
        reduceNow(ControlRequest(source: source, kind: .pause, display: nil, wantsBoost: false))
    }

    /// Ends a user pause.
    public func resume(source: ControlSource) {
        settings[AutomationSettings.pausedUntil] = nil
        pauseSlot.cancel()
        armedPauseDeadline = nil
        reduceNow(ControlRequest(source: source, kind: .resume, display: nil, wantsBoost: false))
    }

    /// S2/S3 (and S1 on Compatibility-mode displays, decided by the reducer): continue until that app quits or
    /// Overbright relaunches. Clears the drift trips the app caused.
    public func continueAnyway(_ app: ConflictingApp) {
        continued[app.entryID] = app.processID
        for controller in controllers.values {
            switch controller.trip {
            case .attributedDrift(let culprit) where culprit.entryID == app.entryID: controller.clearTrip()
            case .repairBudgetExceeded: controller.clearTrip()
            default: break
            }
        }
        reduceNow()
    }

    /// Try Again: clears any trip on this display (the only way to clear flicker, repair and drift trips).
    public func retry(_ display: DisplayKey) {
        controllers[display]?.clearTrip()
        reduceNow()
    }

    // MARK: Helpers

    /// `pairs` by display key; a key seen twice keeps its first value. Display keys are not guaranteed unique (two
    /// monitors with identical EDIDs can share a CoreGraphics UUID), and a request must never trap (§9.2).
    static func byKey<Value>(_ pairs: [(DisplayKey, Value)]) -> [DisplayKey: Value] {
        Dictionary(pairs, uniquingKeysWith: { first, _ in first })
    }

    /// Stores levels (the linked level when linked), turns on, ends a user pause, checks the low-level rule, reduces.
    func applyLevels(_ levels: [DisplayKey: LevelPosition], source: ControlSource, display: DisplayKey?) {
        guard let first = levels.first else { return }
        let linked = settings[DisplaySettings.linkLevels]
        let keys = linked ? displays.displays.map(\.ref.key) : Array(levels.keys)
        let priorStored = Self.byKey(keys.map { ($0, storedLevel(of: $0)) })
        // Every reader (the reducer below, the UI, Signals) sees the new levels at once; UserDefaults gets them once
        // the steps pause (`armLevelPersist`).
        if linked {
            settings.setDeferringWrite(DisplaySettings.linkedLevel, display.flatMap { levels[$0] } ?? first.value)
        } else {
            var all = settings[DisplaySettings.perDisplay]
            for (key, level) in levels {
                var preferences = all[key] ?? DisplayPreferences()
                preferences.level = level
                if source == .panel, display == key, level.isBoost { enableBoostIfOptIn(&preferences, key: key) }
                all[key] = preferences
            }
            settings.setDeferringWrite(DisplaySettings.perDisplay, all)
        }
        armLevelPersist()
        if settings[AutomationSettings.pausedUntil] != nil {
            settings[AutomationSettings.pausedUntil] = nil
            pauseSlot.cancel()
            armedPauseDeadline = nil
        }
        let wantsBoost = keys.contains { storedLevel(of: $0).isBoost }
        if isMasterOn {
            if wantsBoost { refreshPowerBeforeABoost() }
        } else {
            turnOn(source: source)
        }
        askToKeep(priorStored: priorStored, source: source, display: display)
        reduceNow(ControlRequest(source: source, kind: .level, display: display, wantsBoost: wantsBoost))
    }

    /// Levels reach UserDefaults `levelPersistDelay` after the last change: a drag of ten steps a second encodes every
    /// display's preferences and messages cfprefsd once, not ten times. Stop, quit and every turn-off write at once.
    /// One task per pause, not one per step: it sleeps again for the rest of the delay while steps keep coming (a
    /// cancelled sleep would wake the process once per step).
    func armLevelPersist() {
        lastLevelChangeAt = time.now
        guard !levelPersistSlot.isRunning else { return }
        #if DEBUG
        levelPersistTaskCount += 1
        #endif
        levelPersistSlot.run { [weak self] in
            while true {
                guard let self else { return }
                let left = self.lastLevelChangeAt + EngineTiming.levelPersistDelay - self.time.now
                guard left > .zero else { break }
                do { try await self.time.sleep(for: left) } catch { return }
            }
            self?.settings.writeDeferred()
        }
    }

    /// Writes the levels still owed to UserDefaults now.
    func persistLevels() {
        levelPersistSlot.cancel()
        settings.writeDeferred()
    }

    /// Moving the panel's thumb past the detent turns an opt-in display's extra brightness on; an OLED display needs
    /// its notice answered first (the UI shows it, DESIGN.md §5.4).
    func enableBoostIfOptIn(_ preferences: inout DisplayPreferences, key: DisplayKey) {
        guard preferences.boostEnabled != true, let facts = displays.facts(for: key) else { return }
        if Self.isOLED(facts, preferences), !preferences.oledNoticeAcknowledged { return }
        let enabledByDefault = lastDecision?.displays[key]?.eligibility.defaultBoostEnabled ?? false
        if preferences.boostEnabled == false || !enabledByDefault { preferences.boostEnabled = true }
    }

    /// The stored level of a display (the linked level while linked; Bright room for a display never set).
    func storedLevel(of key: DisplayKey) -> LevelPosition {
        if settings[DisplaySettings.linkLevels] { return settings[DisplaySettings.linkedLevel] }
        return settings[DisplaySettings.perDisplay][key]?.level ?? DisplayPreferences().level
    }

    /// Standard light at a level: the dim light on the dim half, 1 otherwise.
    func light(of level: LevelPosition) -> Double { level.isDim ? LevelMapping.dimLight(for: level) : 1 }

    /// Displays that can dim (by the last decision's verdict; a table or the overlay when there is none yet).
    func dimmableKeys() -> [DisplayKey] {
        displays.displays.filter { facts in
            if let verdict = lastDecision?.displays[facts.ref.key]?.eligibility.verdict, verdict != .checking {
                return verdict.allowsDim
            }
            return facts.gammaCapacity > 0
        }.map(\.ref.key)
    }

    /// The gain at the top of the boost half for a display in its cap mode (the verdict's slider tops at full
    /// brightness; `GainCeiling.sliderTop` when there is no verdict yet).
    func top(for key: DisplayKey) -> Double {
        let preferences = settings[DisplaySettings.perDisplay][key] ?? DisplayPreferences()
        switch lastDecision?.displays[key]?.eligibility.verdict {
        case .supported(let safe, let peak)?:
            return preferences.capMode == .safe ? (safe ?? 1) : peak
        case .noGainAtFullBrightness(let peak)?:
            return peak
        default:
            guard let facts = displays.facts(for: key) else { return 1 }
            return GainCeiling.sliderTop(facts: facts, capMode: preferences.capMode,
                                         isOLED: Self.isOLED(facts, preferences))
        }
    }
}
