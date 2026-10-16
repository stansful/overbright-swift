// OverbrightBoost/Engine/DisplayController.swift — the per-display state machine. ARCHITECTURE.md §4.2 (states),
// §4.3 (transitions), §4.5 (invariants), §4.6 (generations and the hang epoch). MainActor.
// This file holds the state, the decision entry point and the shared helpers; the arming and gate loop live in
// `DisplayController+Arming.swift`, ramps and raises in `+Ramping`, events and re-basing in `+Events`, the drift
// check in `+Drift`, and the self-test/calibration seam in `+Driving`.
import Foundation
import OverbrightCore
import OverbrightPolicy
import os

private let log = Log.logger(.engine)

/// One display's engine: trigger or overlay handle, baseline, applied factor, generation, epoch stamp and its tasks
/// (gate poll, poll burst, ramp, drift check, linger, re-base). Every table write goes through `TableWriter`.
@MainActor final class DisplayController {
    /// The ports and shared state every controller uses (the engine owns them).
    struct Dependencies {
        let gamma: any GammaPort
        let writer: TableWriter
        let ledger: SafetyLedger
        let headroom: any HeadroomPort
        let triggers: any TriggerFactory
        let conflicts: any ConflictProbe
        let time: any TimeSource
        let journal: any DiagnosticsJournal
        let cache: StrategyCache
        let ownEDRSurfaces: OwnEDRSurfaces
        let machine: MachineIdentity
    }

    /// What ended a shield, which decides how a suspended display comes back (§4.3).
    enum ResumeKind: Hashable, Sendable {
        /// Wake or lid open: settle 1 s, then the cached rung only, with backoff.
        case wake
        /// Unlock or screensaver stop: the cached rung only, with backoff.
        case unlock
    }

    /// Who asked for a change, for the rate limiter and the oscillation detector.
    typealias Origin = FlickerGuard.Origin

    let deps: Dependencies
    /// The display (its ID changes after a reconfiguration).
    var ref: DisplayRef
    /// Its facts.
    var facts: DisplayFacts
    /// Called after every change the engine publishes; `true` asks for a re-reduction (the feedback changed).
    var onChange: ((Bool) -> Void)?

    // MARK: Decision

    var decision: DisplayDecision?
    var parameters = WriteParameters()
    var target: BoostTarget = .neutral
    var phase: EnginePhase = .idle {
        didSet { if phase != oldValue { phaseChanged(from: oldValue) } }
    }
    var trip: TripCause?
    var failedTries = 0
    /// The potential when the display last failed for lack of headroom (a change retries, §4.3).
    var potentialAtFailure: Double?

    // MARK: Tables

    var baseline: GammaTable?
    var appliedGain = 1.0
    var appliedFactor = 1.0
    var appliedLimit: LimitReason?
    var mechanism: Mechanism = .table
    var domain: TransferDomain = .encoded
    /// Sessions off the console write nothing (D27); set by the session events, mirrored from the snapshot.
    var isOffConsole = false
    /// A mechanism change waits for the display to reach idle, then asks for a re-reduction.
    var switchesMechanism = false

    // MARK: Trigger, overlay and the gate

    var trigger: (any TriggerHandle)?
    var overlay: (any OverlayHandle)?
    var rungs: [LadderRung] = []
    var rungPosition = 0
    var currentRung: LadderRung?
    var idleHeadroom = 1.0
    var gatePath: GateEvaluator.Path = .normal
    var samples: [GateEvaluator.Sample] = []
    var presentedAt: MonotonicInstant?
    var movedAt: MonotonicInstant?
    var armedPreHeld = false
    var preHeldHeadroom: Double?
    var lastReading: HeadroomReading?
    var backoff: (kind: ResumeKind, step: Int)?
    var pendingResume: ResumeKind?
    var quarantineUntil: MonotonicInstant?
    var cachedRungFailedThisArm = false
    var belowNeededSince: MonotonicInstant?

    // MARK: Async state

    var generation: UInt64 = 0
    var rampSerial: UInt64 = 0
    var epochStamp: UInt64 = 0
    let armSlot = TaskSlot()
    let rampSlot = TaskSlot()
    let driftSlot = TaskSlot()
    let burstSlot = TaskSlot()
    let lingerSlot = TaskSlot()
    let checkSlot = TaskSlot()
    let rebaseSlot = TaskSlot()
    var flicker = FlickerGuard()
    var repairs: [MonotonicInstant] = []
    var unexplainedAdoptions: [MonotonicInstant] = []
    var lastBaseEventAt: MonotonicInstant?

    /// A controller for `facts`; constructing it does nothing.
    init(facts: DisplayFacts, dependencies: Dependencies) {
        self.facts = facts
        self.ref = facts.ref
        self.deps = dependencies
        epochStamp = dependencies.ledger.hangEpoch
    }

    // MARK: Reading state

    /// The display's key.
    var key: DisplayKey { ref.key }
    /// The table (or overlay) differs from the baseline: scaled or dimmed.
    var isScaledOrDimmed: Bool { abs(appliedFactor - 1) > TableWriter.neutralTolerance }
    /// Any phase that does work or holds a window (everything but idle and failed).
    var isActive: Bool {
        switch phase {
        case .idle, .failed: false
        default: true
        }
    }
    /// Arming or gating: preparing.
    var isPreparing: Bool {
        switch phase {
        case .arming, .gating: true
        default: false
        }
    }
    /// Number of tasks alive (zero while idle, §4.5 invariant 4).
    var activeTaskCount: Int {
        [armSlot, rampSlot, driftSlot, burstSlot, lingerSlot, checkSlot, rebaseSlot].filter(\.isRunning).count
    }
    /// The boost the current target asks for (nil when the target is not a boost).
    var targetGain: Double? {
        if case .boost(let gain) = target { return gain }
        return nil
    }

    /// What the UI reads.
    func status() -> DisplayStatus {
        DisplayStatus(key: key, name: facts.name, phase: phase, decision: decision, appliedGain: appliedGain,
                      appliedFactor: appliedFactor, mechanism: mechanism,
                      strategy: trigger != nil ? currentRung?.strategy : nil, lastReading: lastReading,
                      sdrWhite: parameters.sdrWhite, failedTries: failedTries)
    }

    // MARK: Decisions

    /// Applies the reducer's decision for this display. `requested` marks a change the user asked for (slider,
    /// preset, step, intent, Focus): it raises at once and never counts towards the oscillation detector.
    func update(_ decision: DisplayDecision, parameters: WriteParameters, requested: Bool) {
        let parametersChanged = parameters != self.parameters
        self.decision = decision
        self.parameters = parameters
        domain = decision.domain
        let changed = !Self.sameTarget(decision.target, target)
        target = decision.target
        guard !isOffConsole, parameters.isSessionActive else { return }
        if decision.mechanism != mechanism {
            guard isActive || isScaledOrDimmed else {
                mechanism = decision.mechanism
                return update(decision, parameters: parameters, requested: requested)
            }
            // Switch mechanisms through neutral: disarm, then the next reduction arms the other one.
            switchesMechanism = true
            disarm(kind: rampKind)
            return
        }
        switch phase {
        case .failed:
            return
        case .suspended(let cause):
            resumeIfPossible(cause, requested: requested)
            return
        case .disarming:
            if case .neutral = target { return }
        default:
            break
        }
        if !changed {
            if parametersChanged, case .boost(let gain) = target, phase == .boosted { adjustBoost(gain, requested: true) }
            return
        }
        switch target {
        case .neutral: disarm(kind: rampKind)
        case .dim(let light): goDim(light, origin: requested ? .user : .automatic)
        case .boost(let gain): goBoost(gain, requested: requested)
        }
    }

    /// The ramp duration for policy and user changes now (Reduce Motion shortens it, never to a snap).
    var rampKind: RampPlanner.Kind { parameters.reduceMotion ? .reduceMotion : .standard }

    func goBoost(_ gain: Double, requested: Bool) {
        switch phase {
        case .idle, .dimmed:
            beginArm()
        case .arming, .gating, .suspended, .failed:
            break
        case .disarming:
            if trigger != nil || overlay != nil, appliedGain >= 1 {
                phase = .boosted
                adjustBoost(gain, requested: true)
            } else {
                beginArm()
            }
        case .ramping, .boosted:
            if trigger == nil && overlay == nil { beginArm() } else { adjustBoost(gain, requested: requested) }
        }
    }

    func goDim(_ light: Double, origin: Origin) {
        switch phase {
        case .idle:
            generation += 1
            guard mechanism == .overlay || captureBaseline() else { return }
            epochStamp = deps.ledger.hangEpoch
            startRamp(to: light, origin: origin, finalPhase: .dimmed)
        case .dimmed:
            startRamp(to: light, origin: origin, finalPhase: .dimmed)
        case .arming, .gating:
            generation += 1
            armSlot.cancel(); burstSlot.cancel()
            removeWindows()
            startRamp(to: light, origin: origin, finalPhase: .dimmed)
        case .ramping, .boosted, .disarming:
            generation += 1
            armSlot.cancel(); burstSlot.cancel(); driftSlot.cancel()
            startRamp(to: light, origin: origin, finalPhase: .dimmed, removesWindowsAtEnd: true)
        case .suspended, .failed:
            break
        }
    }

    /// Ramp to 1 → baseline → remove the trigger (§4.5 invariant 2) → idle. The quit's stop is not rate-limited.
    func disarm(kind: RampPlanner.Kind, rateLimited: Bool = true) {
        switch phase {
        case .idle, .failed:
            return
        case .suspended:
            generation += 1
            cancelAllTasks()
            writeBaselineNow()
            removeWindows()
            phase = .idle
        default:
            generation += 1
            armSlot.cancel(); burstSlot.cancel(); driftSlot.cancel(); rebaseSlot.cancel(); lingerSlot.cancel()
            guard isScaledOrDimmed else {
                rampSlot.cancel()
                removeWindows()
                phase = .idle
                return
            }
            phase = .disarming
            startRamp(to: 1, kind: kind, origin: .automatic, finalPhase: .idle, removesWindowsAtEnd: true,
                      setsRampingPhase: false, rateLimited: rateLimited)
        }
    }

    // MARK: Trips

    /// Lands on neutral at once (one write), removes every window and records `cause` as the feedback.
    func fail(_ cause: TripCause) {
        generation += 1
        cancelAllTasks()
        writeBaselineNow()
        removeWindows()
        if case .headroomNeverArrived = cause {
            failedTries += 1
            potentialAtFailure = lastReading?.potential
        }
        trip = cause
        deps.journal.record(Self.tripCode(cause), display: key, time: deps.time)
        log.info("display failed: \(Self.tripCode(cause), privacy: .public)")
        phase = .failed(cause)
        notify(needsReduction: true)
    }

    /// Try Again (and the automatic retries of §4.3): clears the trip; the next reduction re-arms.
    func clearTrip() {
        guard trip != nil || phase.isFailed else { return }
        generation += 1
        cancelAllTasks()
        trip = nil
        potentialAtFailure = nil
        flicker.reset()
        repairs = []
        unexplainedAdoptions = []
        phase = .idle
        notify(needsReduction: true)
    }

    /// Records a trip found outside the state machine (the launch check's residue).
    func setTrip(_ cause: TripCause) {
        fail(cause)
    }

    // MARK: Shared helpers

    /// A fresh reading of this display (nil without its own NSScreen), kept as `lastReading`.
    @discardableResult
    func takeReading() -> HeadroomReading? {
        let reading = deps.headroom.reading(for: ref)
        if let reading { lastReading = reading }
        return reading
    }

    /// Whether async work stamped with `stamp` is still current (§4.6).
    func isCurrent(_ stamp: UInt64) -> Bool { stamp == generation }

    /// Sleeps on the time source; false when cancelled or superseded.
    func sleep(_ duration: Duration, _ stamp: UInt64) async -> Bool {
        do { try await deps.time.sleep(for: duration) } catch { return false }
        return isCurrent(stamp)
    }

    /// Writes the baseline now when the table (or overlay) is scaled or dimmed (one write, never refused).
    func writeBaselineNow() {
        defer { appliedGain = 1; appliedFactor = 1; appliedLimit = nil }
        guard isScaledOrDimmed else { return }
        if mechanism == .overlay {
            try? overlay?.setFactor(1, headroomRequest: 1)
            return
        }
        guard let baseline else { return }
        do {
            try deps.writer.writeBaseline(baseline, to: ref)
        } catch {
            deps.journal.record("baseline.writeFailed", display: key, time: deps.time, category: .gamma)
            log.error("baseline write failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Orders out the trigger and the overlay (after the table is back at its baseline, §4.5 invariant 2).
    func removeWindows() {
        let windows = (trigger, overlay)
        trigger = nil
        overlay = nil
        windows.0?.remove()
        windows.1?.remove()
        lingerSlot.cancel()
    }

    /// Cancels every task of this controller.
    func cancelAllTasks() {
        rampSerial &+= 1
        for slot in [armSlot, rampSlot, driftSlot, burstSlot, lingerSlot, checkSlot, rebaseSlot] { slot.cancel() }
    }

    /// Tells the engine to publish (and, with `needsReduction`, to re-reduce).
    func notify(needsReduction: Bool = false) { onChange?(needsReduction) }

    /// The request the writer needs for `gain`.
    func writeRequest(_ gain: Double, baseline: GammaTable) -> TableWriter.Request {
        TableWriter.Request(gain: gain, domain: domain, baseline: baseline, facts: facts, capMode: parameters.capMode,
                            isOLED: parameters.isOLED, sdrWhite: parameters.sdrWhite, taper: parameters.taper,
                            fullBrightnessHeadroom: fullBrightnessHeadroom)
    }

    /// The taper's reference (§5.4): the lowest ready headroom of this display and OS build, never above the seed
    /// `panelPeak ÷ sdrMax`.
    var fullBrightnessHeadroom: Double? {
        let seed = GainCeiling.fullBrightnessHeadroomSeed(facts: facts)
        let learned = deps.cache.record(for: key, osBuild: deps.machine.osBuild)?.lowestReadyHeadroom
        switch (seed, learned) {
        case let (seed?, learned?): return min(seed, learned)
        case let (seed?, nil): return seed
        case let (nil, learned?): return learned
        case (nil, nil): return nil
        }
    }

    private func phaseChanged(from old: EnginePhase) {
        deps.journal.record("phase." + Self.phaseCode(phase), display: key, time: deps.time)
        log.info("phase \(Self.phaseCode(old), privacy: .public) → \(Self.phaseCode(self.phase), privacy: .public)")
        notify()
    }

    static func sameTarget(_ a: BoostTarget, _ b: BoostTarget) -> Bool {
        switch (a, b) {
        case (.neutral, .neutral): true
        case (.dim(let x), .dim(let y)), (.boost(let x), .boost(let y)): abs(x - y) <= 1e-9
        default: false
        }
    }

    static func phaseCode(_ phase: EnginePhase) -> String {
        switch phase {
        case .idle: "idle"
        case .dimmed: "dimmed"
        case .arming: "arming"
        case .gating: "gating"
        case .ramping: "ramping"
        case .boosted: "boosted"
        case .suspended: "suspended"
        case .failed: "failed"
        case .disarming: "disarming"
        }
    }

    static func tripCode(_ cause: TripCause) -> String {
        switch cause {
        case .oscillation: "flicker.trip"
        case .repairBudgetExceeded: "repair.trip"
        case .attributedDrift: "drift.attributedTrip"
        case .headroomNeverArrived: "gate.neverArrived"
        case .foreignTableAtLaunch: "baseline.foreignAtLaunch"
        }
    }
}

extension EnginePhase {
    /// `failed(_)`, whatever the cause.
    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}
