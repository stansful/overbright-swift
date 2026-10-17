// OverbrightBoost/Engine/BoostEngine+Policy.swift — the policy loop: build the `PolicyInput`, call the injected
// reducer, hand each controller its decision, publish HUD changes. ARCHITECTURE.md §3.4, §4.1 (re-reduction coalesced
// to one per run-loop turn, never by polling), §4.9 (HUD changes), §6.1; DESIGN.md §6. MainActor.
import Foundation
import OverbrightCore
import OverbrightPolicy

extension BoostEngine {
    /// A change somebody asked for: decides the HUD (`lastChange`) and whether raises apply at once.
    struct ControlRequest: Hashable, Sendable {
        enum Kind: Hashable, Sendable { case turnOn, turnOff, level, backToStandard, pause, resume }
        var source: ControlSource
        var kind: Kind
        var display: DisplayKey?
        /// The change asks for the boost half (a turn-on, or a level above Standard): a guard that stops it is shown
        /// as `.blocked`.
        var wantsBoost: Bool
        /// Raises apply at once and never count towards the oscillation detector; automation is not a user change.
        var isUserChange: Bool { source != .automation && source != .launch }
    }

    /// Sources whose level and on/off changes the HUD shows (DESIGN.md §6; Back to Standard from any source).
    static let levelSources: Set<ControlSource> = [.shortcut, .intent, .focusFilter]
    /// Sources whose turn-on shows "Preparing…" after 0.5 s.
    static let preparingSources: Set<ControlSource> = [.statusItem, .shortcut, .intent]
    /// Sources whose requests show `.blocked(reason)` when a guard stops them.
    static let blockingSources: Set<ControlSource> = [.statusItem, .shortcut, .intent, .focusFilter]

    // MARK: Inputs

    /// Everything a reduction reads that can change without an event (settings, the snapshot, the directory, own EDR
    /// surfaces): observed, so a change schedules one coalesced re-reduction.
    struct ObservedInputs: Equatable {
        var settings: PolicySettings
        var perDisplay: [DisplayKey: DisplayPreferences]
        var pausedUntil: Date?
        var snapshot: SystemSnapshot
        var directoryGeneration: Int
        var ownSurfaces: [DisplayKey: Int]
    }

    func observedInputs() -> ObservedInputs {
        ObservedInputs(settings: policySettings(), perDisplay: settings[DisplaySettings.perDisplay],
                       pausedUntil: settings[AutomationSettings.pausedUntil], snapshot: signals.snapshot,
                       directoryGeneration: displays.generation, ownSurfaces: ownEDRSurfaces.displays)
    }

    /// The observed inputs changed: follow the directory and the Focus filter, then re-reduce.
    func inputsChanged() {
        guard isStarted else { return }
        if displays.generation != lastDirectoryGeneration { syncControllers(reconfigured: false) }
        let focus = signals.snapshot.focus
        if focus != lastFocus {
            lastFocus = focus
            if case .on = focus {
                if isMasterOn { refreshPowerBeforeABoost() } else { turnOn(source: .focusFilter) }
                reduceNow(ControlRequest(source: .focusFilter, kind: .turnOn, display: nil, wantsBoost: true))
                return
            }
            if focus == .off {
                reduceNow(ControlRequest(source: .focusFilter, kind: .level, display: nil, wantsBoost: false))
                return
            }
        }
        scheduleReduce()
    }

    /// The settings the reducer reads, flattened from the keys catalog (§3.8).
    func policySettings() -> PolicySettings {
        PolicySettings(batteryGuard: settings[AutomationSettings.batteryGuard],
                       batteryThreshold: settings[AutomationSettings.batteryThreshold],
                       pauseInLowPowerMode: settings[AutomationSettings.pauseInLowPowerMode],
                       pauseForFullScreenVideo: settings[AutomationSettings.pauseForFullScreenVideo],
                       pauseForAllFullScreen: settings[AutomationSettings.pauseForAllFullScreen],
                       pauseInGames: settings[AutomationSettings.pauseInGames],
                       pauseForListedApps: settings[AutomationSettings.pauseForListedApps],
                       pausedApps: settings[AutomationSettings.pausedApps],
                       schedule: settings[AutomationSettings.schedule],
                       linkLevels: settings[DisplaySettings.linkLevels],
                       linkedLevel: settings[DisplaySettings.linkedLevel],
                       boostOnlyNearFullBrightness: settings[DisplaySettings.boostOnlyNearFullBrightness],
                       alwaysContinueEntryIDs: settings[AdvancedSettings.alwaysContinue])
    }

    /// The reducer's input now: settings, the snapshot, every online display with its preferences, feedback (trip, the
    /// latest reading and the taper reference the writer uses) and trusted SDR white.
    func policyInput() -> PolicyInput {
        let now = time.wallClock
        let calendar = Calendar.current
        let minute = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let perDisplay = settings[DisplaySettings.perDisplay]
        let inputs = displays.displays.map { facts -> DisplayPolicyInput in
            let key = facts.ref.key
            let preferences = perDisplay[key] ?? DisplayPreferences()
            let controller = controllers[key]
            let reading = controller?.feedbackReading()
            let mechanism = lastDecision?.displays[key]?.mechanism ?? .table
            return DisplayPolicyInput(facts: facts, preferences: preferences,
                                      feedback: EngineFeedback(trip: controller?.trip, lastReading: reading,
                                                               fullBrightnessHeadroom: controller?.fullBrightnessHeadroom),
                                      sdrWhite: SDRWhiteSource.estimate(facts: facts, preferences: preferences,
                                                                        mechanism: mechanism, machine: machine,
                                                                        reading: reading))
        }
        return PolicyInput(isMasterOn: isMasterOn, pausedUntil: settings[AutomationSettings.pausedUntil], now: now,
                           minuteOfDay: minute, machine: machine, settings: policySettings(), system: signals.snapshot,
                           displays: inputs, continuedEntryIDs: Set(continued.keys))
    }

    /// What a controller needs besides its decision.
    func parameters(for facts: DisplayFacts, decision: DisplayDecision, snapshot: SystemSnapshot) -> WriteParameters {
        let preferences = settings[DisplaySettings.perDisplay][facts.ref.key] ?? DisplayPreferences()
        let sdrWhite = SDRWhiteSource.estimate(facts: facts, preferences: preferences, mechanism: decision.mechanism,
                                               machine: machine, reading: controllers[facts.ref.key]?.lastReading)
        return WriteParameters(capMode: preferences.capMode, isOLED: Self.isOLED(facts, preferences),
                               sdrWhite: sdrWhite,
                               colorimeterHeadroom: sdrWhite?.source == .colorimeter
                                   ? preferences.calibration?.headroomAtTest : nil,
                               taper: settings[DisplaySettings.boostOnlyNearFullBrightness],
                               reduceMotion: snapshot.reduceMotion, triggerOverride: preferences.triggerOverride,
                               isHDRSuppressed: snapshot.isHDRSuppressed, isSessionActive: snapshot.isSessionActive)
    }

    /// OLED by the user's override, else by class (minimum luminance, D8).
    static func isOLED(_ facts: DisplayFacts, _ preferences: DisplayPreferences) -> Bool {
        switch preferences.oled {
        case .oled: true
        case .notOLED: false
        case .automatic: facts.panelClass == .oledExternal
        }
    }

    // MARK: Reducing

    /// One coalesced re-reduction on the next main-actor turn.
    func scheduleReduce() {
        guard isStarted, !reducePending else { return }
        reducePending = true
        Task { @MainActor [weak self] in
            guard let self, self.reducePending else { return }
            self.reducePending = false
            self.reduceNow()
        }
    }

    /// Reduces now and applies the decision to every controller (a pending coalesced reduction is subsumed).
    func reduceNow(_ request: ControlRequest? = nil) {
        guard isStarted else { return }
        reducePending = false
        refreshDeadlines()
        let input = policyInput()
        let decision = reduce(input)
        let previous = lastDecision
        lastDecision = decision
        isApplying = true
        for facts in displays.displays {
            guard let controller = controllers[facts.ref.key] else { continue }
            let displayDecision = decision.displays[facts.ref.key] ?? Self.neutralDecision(for: facts)
            controller.update(displayDecision, parameters: parameters(for: facts, decision: displayDecision,
                                                                       snapshot: input.system),
                              requested: request?.isUserChange ?? false)
        }
        isApplying = false
        recordChange(previous: previous, decision: decision, request: request, system: input.system)
        updateAggregates()
        publish()
    }

    /// A display the reducer did not decide for stays neutral.
    static func neutralDecision(for facts: DisplayFacts) -> DisplayDecision {
        DisplayDecision(key: facts.ref.key, target: .neutral, reasons: [],
                        eligibility: EligibilityResult(verdict: .checking, advisories: [], defaultBoostEnabled: false,
                                                       defaultMechanism: .table),
                        mechanism: .table, domain: .encoded, requestedGain: 1)
    }

    // MARK: HUD changes (DESIGN.md §6)

    /// Publishes `lastChange` for a request (level, blocked, preparing) or for an automation that stopped, capped or
    /// resumed the boost on a visible display. Never for full-screen, app or game pauses.
    func recordChange(previous: PolicyDecision?, decision: PolicyDecision, request: ControlRequest?,
                      system: SystemSnapshot) {
        if let request {
            if request.wantsBoost, Self.blockingSources.contains(request.source), let reason = blockingReason(decision) {
                emitChange(.blocked(reason), source: request.source, display: request.display)
            } else if request.kind == .backToStandard || Self.levelSources.contains(request.source) {
                emitChange(.level, source: request.source, display: request.display)
            }
            if request.kind == .turnOn, Self.preparingSources.contains(request.source) {
                armPreparingCheck(source: request.source)
            }
            return
        }
        guard isMasterOn, !system.isShielded else { return }
        let before = previous.flatMap(automationReason), after = automationReason(decision)
        if let after, before.map({ Self.reasonKind($0) != Self.reasonKind(after) }) ?? true {
            emitChange(.automationStopped(after), source: .automation, display: nil)
        } else if before != nil, after == nil,
                  decision.displays.values.contains(where: { if case .boost = $0.target { true } else { false } }) {
            emitChange(.automationResumed, source: .automation, display: nil)
        }
    }

    /// Increments the sequence and publishes the change.
    func emitChange(_ kind: LevelChange.Kind, source: ControlSource, display: DisplayKey?) {
        changeSequence += 1
        lastChange = LevelChange(sequence: changeSequence, kind: kind, source: source, display: display)
        journal.record("hud.change", display: display, values: ["sequence": Double(changeSequence)], time: time)
    }

    /// The guard that stops a requested boost on every display (nil when some display boosts or nothing guards).
    func blockingReason(_ decision: PolicyDecision) -> LimitReason? {
        let ordered = displays.displays.compactMap { decision.displays[$0.ref.key] }
        guard !ordered.contains(where: { if case .boost = $0.target { true } else { false } }) else { return nil }
        for display in ordered {
            if let reason = display.reasons.first(where: Self.isGuard) { return reason }
        }
        return nil
    }

    /// Guards and pauses (not the master switch, eligibility, shields, trips, caps or the per-display switch).
    static func isGuard(_ reason: LimitReason) -> Bool {
        switch reason {
        case .userPaused, .focusOff, .conflict: true
        case .boostNotEnabled: false
        default: reason.blocksBoostOnly
        }
    }

    /// The first automation reason (timer excluded: it has its own change) in any display's reasons.
    func automationReason(_ decision: PolicyDecision) -> LimitReason? {
        for facts in displays.displays {
            guard let reasons = decision.displays[facts.ref.key]?.reasons else { continue }
            if let reason = reasons.first(where: Self.isAutomation) { return reason }
        }
        return nil
    }

    /// Battery, Low Power, heat and the schedule (DESIGN.md §6 (4)).
    static func isAutomation(_ reason: LimitReason) -> Bool {
        switch reason {
        case .battery, .onBattery, .lowPowerMode, .thermalCritical, .thermalSerious, .outsideSchedule: true
        default: false
        }
    }

    /// The case of a reason without its values (a battery percentage that moves is the same automation).
    static func reasonKind(_ reason: LimitReason) -> String {
        switch reason {
        case .battery: "battery"
        default: String(describing: reason)
        }
    }

    /// "Preparing…" when a turn-on from the icon, a shortcut or an intent is not ready within 0.5 s.
    func armPreparingCheck(source: ControlSource) {
        preparingSlot.run { [weak self] in
            guard let self else { return }
            do { try await self.time.sleep(for: EngineTiming.preparingDelay) } catch { return }
            guard self.isMasterOn, self.isPreparingNow else { return }
            self.emitChange(.preparing, source: source, display: nil)
            self.publish()
        }
    }
}

extension DisplayController {
    /// The reading the reducer sees: a fresh one while the display does no work of its own (idle, failed), so the
    /// verdict follows the display (HDR switched on, a preset change); the latest poll otherwise.
    func feedbackReading() -> HeadroomReading? {
        switch phase {
        case .idle, .failed: takeReading() ?? lastReading
        default: lastReading
        }
    }
}
