// OverbrightPolicy/Reducer/DisplayReducer.swift — the per-display algorithm and precedence of ARCHITECTURE.md §6.1
// (steps 1–8, rows 1–19), §5.4 (static caps) and §7.2 (conflict continuation). Pure: every input is in `PolicyInput`.
import Foundation
import OverbrightCore

/// Walks §6.1 for one display at a time. Every matching stop and boost-only guard is recorded in precedence order
/// (the first sets `.neutral` and is the chip), so the banner can choose among all of them (§6.3) and the next reason
/// is already there when the first clears.
nonisolated struct DisplayReducer: Sendable {
    /// Below this the boost asks for nothing: the target is neutral (the engine would only arm a trigger, §5.4 step 3).
    static let noOpGain = 1.005

    let input: PolicyInput
    /// The user pause, when it is still running at `input.now`.
    let pausedUntil: Date?

    init(input: PolicyInput) {
        self.input = input
        pausedUntil = input.pausedUntil.flatMap { $0 > input.now ? $0 : nil }
    }

    func outcome(for display: DisplayPolicyInput) -> DisplayOutcome {
        let facts = display.facts
        let preferences = display.preferences
        let reading = display.feedback.lastReading
        // Steps 1–5.
        let eligibility = EligibilityClassifier.classify(facts, preferences: preferences, reading: reading,
                                                         machine: input.machine)
        let isOLED = EligibilityClassifier.isOLED(facts, override: preferences.oled)
        let boostEnabled = preferences.boostEnabled ?? eligibility.defaultBoostEnabled
        var level = input.settings.linkLevels ? input.settings.linkedLevel : preferences.level
        if case .on(let focusLevel) = input.system.focus { level = focusLevel }
        let mechanism = EligibilityClassifier.effectiveMechanism(preferences.mechanism,
                                                                 defaultMechanism: eligibility.defaultMechanism)
        let domain = TransferDomainResolver.effectiveDomain(preferences.calibration, mechanism: mechanism,
                                                            machine: input.machine, potential: reading?.potential)
        let top = GainCeiling.sliderTop(facts: facts, capMode: preferences.capMode, isOLED: isOLED)
        let peakTop = GainCeiling.sliderTop(facts: facts, capMode: .peak, isOLED: isOLED)
        let requested = LevelMapping.requestedGain(for: level, top: top)
        let verdict = eligibility.verdict
        let halfAllowed = level.isBoost ? verdict.allowsBoost && peakTop > 1 : level.isDim ? verdict.allowsDim : true
        // The boost half can change this display in its cap mode (Safe can be disabled while Peak is not).
        let boosts = level.isBoost && halfAllowed && top > 1

        func decision(_ target: BoostTarget, _ reasons: [LimitReason]) -> DisplayOutcome {
            DisplayOutcome(
                decision: DisplayDecision(key: facts.ref.key, target: target, reasons: reasons,
                                          eligibility: eligibility, mechanism: mechanism, domain: domain,
                                          requestedGain: requested, level: level),
                requestsChange: level.isDim ? halfAllowed : boosts, requestsBoost: boosts)
        }

        // Step 6, row 1.
        guard input.isMasterOn else { return decision(.neutral, [.masterOff]) }
        // Rows 2–18.
        var stops = stopReasons(display, verdict: verdict, halfAllowed: halfAllowed, mechanism: mechanism)
        if level.isBoost { stops += guardReasons(display, boostEnabled: boostEnabled, isOLED: isOLED) }
        // Row 19: a reason only.
        let suppression: [LimitReason] = level.isBoost && input.system.isHDRSuppressed ? [.hdrSuppressedByMacOS] : []
        if !stops.isEmpty { return decision(.neutral, stops + suppression) }

        // Step 7.
        let advisory = conditionalConflicts
        if level.isDim { return decision(.dim(light: LevelMapping.dimLight(for: level)), advisory) }
        guard level.isBoost else { return decision(.neutral, []) }
        let capped = caps(display, requested: requested, level: level, top: top, peakTop: peakTop, isOLED: isOLED)
        let reasons = suppression + capped.reasons + advisory
        return decision(capped.gain < Self.noOpGain ? .neutral : .boost(gain: capped.gain), reasons)
    }

    // MARK: Stops (rows 2–7) and boost-only guards (rows 8–18)

    private func stopReasons(_ display: DisplayPolicyInput, verdict: DisplayVerdict, halfAllowed: Bool,
                             mechanism: Mechanism) -> [LimitReason] {
        var reasons: [LimitReason] = []
        if !halfAllowed { reasons.append(.notSupported(verdict)) }
        if input.system.isShielded { reasons.append(.shielded) }
        if let app = blockingConflict(mechanism: mechanism) { reasons.append(.conflict(app)) }
        if let trip = display.feedback.trip { reasons.append(.tripped(trip)) }
        if let pausedUntil { reasons.append(.userPaused(until: pausedUntil)) }
        if input.system.focus == .off { reasons.append(.focusOff) }
        return reasons
    }

    private func guardReasons(_ display: DisplayPolicyInput, boostEnabled: Bool, isOLED: Bool) -> [LimitReason] {
        let settings = input.settings
        let system = input.system
        let power = system.power
        let key = display.facts.ref.key
        var reasons: [LimitReason] = []
        if !boostEnabled { reasons.append(.boostNotEnabled) }
        if system.thermal == .critical { reasons.append(.thermalCritical) }
        if power.isLowPowerMode && settings.pauseInLowPowerMode { reasons.append(.lowPowerMode) }
        if power.source == .battery {
            switch settings.batteryGuard {
            case .onlyOnAdapter:
                reasons.append(.onBattery)
            case .belowThreshold:
                if let percent = power.batteryPercent, percent < settings.batteryThreshold {
                    reasons.append(.battery(percent: percent, threshold: settings.batteryThreshold))
                }
            case .off:
                break
            }
        }
        if let schedule = settings.schedule, !schedule.contains(minuteOfDay: input.minuteOfDay) {
            reasons.append(.outsideSchedule)
        }
        if settings.pauseForFullScreenVideo && system.fullScreenVideoDisplays.contains(key) {
            reasons.append(.fullScreenVideo)
        }
        if settings.pauseForAllFullScreen && system.fullScreenDisplays.contains(key) { reasons.append(.fullScreenApp) }
        if let front = system.frontmost, front.displays.contains(key) {
            if settings.pauseForListedApps, let bundleID = front.bundleID,
               settings.pausedApps.contains(where: { pauses($0, front: front, bundleID: bundleID) }) {
                reasons.append(.pausedApp(bundleID: bundleID))
            }
            if settings.pauseInGames && front.isGame { reasons.append(.game) }
        }
        if isOLED && system.isIdleBeyondThreshold { reasons.append(.oledIdle) }
        return reasons
    }

    /// Row 16: an enabled rule for this exact bundle ID (case-insensitively, as LaunchServices compares them);
    /// `whilePlaying` needs a held display-sleep assertion, and an unknown one falls back to `whileFrontmost` (§6.5).
    private func pauses(_ rule: PausedAppRule, front: FrontmostApp, bundleID: String) -> Bool {
        guard rule.isEnabled, rule.bundleID.lowercased() == bundleID.lowercased() else { return false }
        switch rule.mode {
        case .whileFrontmost: return true
        case .whilePlaying: return front.isPlaying ?? true
        }
    }

    // MARK: Conflicts (§7.2)

    /// The first S1, else S2, app that is not continued. S1 is continued only on an overlay display (it writes no
    /// table); S2 by Continue Anyway in this session or Always Continue.
    private func blockingConflict(mechanism: Mechanism) -> ConflictingApp? {
        let conflicts = input.system.conflicts
        let booster = conflicts.first { app in
            app.severity == .booster && !(input.continuedEntryIDs.contains(app.entryID) && mechanism == .overlay)
        }
        return booster ?? conflicts.first { app in app.severity == .gammaWriter && !isContinued(app) }
    }

    /// S3 apps: a non-blocking reason after the caps, until the user continues with them.
    private var conditionalConflicts: [LimitReason] {
        input.system.conflicts.filter { $0.severity == .conditional && !isContinued($0) }.map { .conflict($0) }
    }

    private func isContinued(_ app: ConflictingApp) -> Bool {
        input.continuedEntryIDs.contains(app.entryID) || input.settings.alwaysContinueEntryIDs.contains(app.entryID)
    }

    // MARK: Caps (step 7, §5.4)

    /// `G_static = min(G_req, trusted SDR white ? capNits ÷ sdrNow : ∞, serious heat ? 1.2 : ∞)`, with the cap
    /// reasons that bind, in order: heat, Safe (or OLED) limit, then the live terms the feedback reading shows.
    private func caps(_ display: DisplayPolicyInput, requested: Double, level: LevelPosition, top: Double,
                      peakTop: Double, isOLED: Bool) -> (gain: Double, reasons: [LimitReason]) {
        let facts = display.facts
        let capMode = display.preferences.capMode
        var gain = requested
        var reasons: [LimitReason] = []
        if input.system.thermal == .serious && GainCeiling.thermalSeriousGain < gain {
            gain = GainCeiling.thermalSeriousGain
            reasons.append(.thermalSerious)
        }
        // Safe binds when Peak would give more and the user is at the top (or the Safe half is disabled), or a
        // trusted SDR white puts the Safe level below the gain.
        var safeBinds = capMode == .safe && top < peakTop && (level.value >= 0.98 || top <= 1)
        if capMode == .safe, let sdr = display.sdrWhite, sdr.nits > 0,
           let capNits = GainCeiling.capNits(facts: facts, isOLED: isOLED), capNits / sdr.nits < gain {
            gain = max(capNits / sdr.nits, 1)
            safeBinds = true
        }
        var live: [LimitReason] = []
        if let reading = display.feedback.lastReading {
            let cap = GainCeiling.liveCap(staticGain: gain, reading: reading, facts: facts, capMode: capMode,
                                          isOLED: isOLED, sdrWhite: display.sdrWhite,
                                          taper: input.settings.boostOnlyNearFullBrightness,
                                          fullBrightnessHeadroom: GainCeiling.fullBrightnessHeadroomSeed(facts: facts))
            switch cap.reason {
            case .safeLimit?: safeBinds = true
            case let reason?: live.append(reason)
            case nil: break
            }
        }
        if safeBinds { reasons.append(isOLED ? .oledLimit : .safeLimit) }
        return (gain, reasons + live)
    }
}
