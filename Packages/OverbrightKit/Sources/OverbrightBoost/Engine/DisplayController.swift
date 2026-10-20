// OverbrightBoost/Engine/DisplayController.swift — the per-display state machine. ARCHITECTURE.md §4.2 (states),
// §4.3 (transitions), §4.5 (invariants), §4.6 (generations and the hang epoch). MainActor.
// This file holds the state; decisions live in `DisplayController+Decisions.swift`, trips and shared helpers in
// `+Support`, arming in `+Arming`, the gate and re-gating in `+Gate`, capture in `+Capture`, ramps and raises in
// `+Ramping`, failed writes in `+WriteFailure`, events in `+Events`, re-basing in `+Rebase`, the drift check in
// `+Drift`, and the self-test and calibration seam in `+Driving`.
import Foundation
import OverbrightCore
import OverbrightPolicy

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
    /// The profile base `baseline` was captured or adopted against (§4.8): a re-base replaces a baseline only when the
    /// profile base moved away from it, so a foreign baseline survives every reconfiguration that changed nothing.
    var expectedBase: GammaTable?
    var appliedGain = 1.0
    var appliedFactor = 1.0
    var appliedLimit: LimitReason?
    var mechanism: Mechanism = .table
    var domain: TransferDomain = .encoded
    /// Sessions off the console write nothing (D27); set by the session events, mirrored from the snapshot.
    var isOffConsole = false
    /// A mechanism change waits for the display to reach idle, then asks for a re-reduction.
    var switchesMechanism = false
    /// The baseline and factor of our latest table write (what the re-base and the drift check expect to read).
    var lastWrite: (baseline: GammaTable, factor: Double)?
    /// A re-base waits for WindowServer's table: the drift check stands aside meanwhile.
    var isRebasing = false
    /// A reconfiguration, ColorSync or accessibility event that no re-base has judged yet (a shield or a stop cut it
    /// short): resuming restarts it, reaching idle or failed judges it at once (§4.8).
    var pendingRebase: ReapplyCause?
    /// The self-test or a calibration drives this display (`DisplayControllerDriving`): decisions are stored, not
    /// applied, until it is handed back. A driven session starts from a freshly captured baseline and stamps the hang
    /// epoch it writes under (a hang restore refuses its later writes until a new session starts, §4.6).
    var isDriven = false {
        didSet {
            if isDriven, !oldValue {
                epochStamp = deps.ledger.hangEpoch
                refreshBaseline()
            } else if !isDriven {
                calibratesOverlay = false
            }
        }
    }
    /// The driven session is a calibration of the Compatibility-mode overlay (set by `beginCalibration`): it arms and
    /// scales the overlay, never the table or a trigger.
    var calibratesOverlay = false
    /// The headroom request of the overlay a calibration armed.
    var drivenOverlayRequest = 1.0
    /// A driven display lost its window (occluded, or moved to another screen): the engine ends the calibration or the
    /// self-test on this display.
    var onDrivenWindowLost: ((CalibrationAbortReason) -> Void)?

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
    /// Gate time spent while macOS asked the app to suppress HDR (`WriteParameters.isHDRSuppressed`): it pauses the
    /// gate timeout only. The stability window keeps measuring from the real movement, so a suppression that never
    /// ends (macOS 27 sends one to a menu-bar agent at launch) can no longer hold the gate open forever (2026-10-20).
    var gatePause: Duration = .zero
    var armedPreHeld = false
    var preHeldHeadroom: Double?
    var lastReading: HeadroomReading?
    /// The reading `status()` publishes: `lastReading` once one of its values moved by `publishedReadingStep` or more
    /// (or the display changed), else the copy published before, so a fresh timestamp alone never republishes the
    /// status. Only the UI reads it; the reducer, the interlock and the writer use fresh readings (§4.5 invariant 1).
    var publishedReading: HeadroomReading?
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
    /// Whether Signals' boost-only sources must run for this display (§7.1, D30, DESIGN.md §17): it arms or gates, or it
    /// ramps toward, holds or disarms from a boost (a boost target, or a table or overlay above its baseline, whatever
    /// the phase). Every guard those sources feed applies to the boost half only (D10: dimming always works), so a
    /// dimmed-only display needs none. Dim → boost does not always arm (an overlay partway through a dim ramp adjusts
    /// that ramp, a disarm whose window is still up goes back to boosted), yet the power source is still read before
    /// any boost write: a level request reads it before reducing while no display keeps the sources running
    /// (`refreshPowerBeforeABoost`), the same reduction ends with `updateAggregates` and the synchronous read of
    /// `setBoostActive(true)`, and every ramp sleeps before its first step (`runRamp`; `BoostSourcesTests`). A
    /// suspended display whose baseline is written needs none until it resumes (a lock, display sleep or fast user
    /// switch can last all night; the resume reads the power source again), and neither does a display the self-test
    /// or a calibration drives (the master is held off). The drift check and the hang watchdog do not depend on this:
    /// they follow the phase and the safety ledger.
    var needsBoostSources: Bool {
        guard !isDriven else { return false }
        if appliedFactor > 1 + TableWriter.neutralTolerance { return true }
        switch phase {
        case .arming, .gating: return true
        case .ramping, .boosted, .disarming: return targetGain != nil
        case .idle, .failed, .suspended, .dimmed: return false
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
    /// The live tasks by name, prefixed with the display ("<key>.ramp"), for diagnostics and tests.
    var activeTaskNames: [String] {
        [("arm", armSlot), ("ramp", rampSlot), ("drift", driftSlot), ("burst", burstSlot), ("linger", lingerSlot),
         ("check", checkSlot), ("rebase", rebaseSlot)].filter { $0.1.isRunning }.map { "\(key.rawValue).\($0.0)" }
    }
    /// The boost the current target asks for (nil when the target is not a boost).
    var targetGain: Double? {
        if case .boost(let gain) = target { return gain }
        return nil
    }

    /// What the UI reads. Its reading is the stable copy (`stableReading()`); the SDR white still follows the fresh one.
    func status() -> DisplayStatus {
        DisplayStatus(key: key, name: facts.name, phase: phase, decision: decision, appliedGain: appliedGain,
                      appliedFactor: appliedFactor, mechanism: mechanism,
                      strategy: trigger != nil ? currentRung?.strategy : nil, lastReading: stableReading(),
                      sdrWhite: sdrWhite(at: lastReading), failedTries: failedTries, lastGrant: lastGrant)
    }

    /// A published reading is replaced once current, potential or reference moved by this much (far below what any
    /// card, chip or marker shows; the HeadroomReading's own time never counts).
    static let publishedReadingStep = 0.0005

    /// `lastReading`, or the reading published before while it is of the same display and none of its values moved by
    /// `publishedReadingStep`; remembers what it returns.
    func stableReading() -> HeadroomReading? {
        guard let reading = lastReading else {
            publishedReading = nil
            return nil
        }
        if let published = publishedReading, published.display == reading.display,
           abs(published.current - reading.current) < Self.publishedReadingStep,
           abs(published.potential - reading.potential) < Self.publishedReadingStep,
           abs(published.reference - reading.reference) < Self.publishedReadingStep {
            return published
        }
        publishedReading = reading
        return reading
    }

    /// The largest light gain macOS's grants allowed here (0.97 × the highest headroom seen while boosting), if any.
    var lastGrant: Double? {
        deps.cache.record(for: key, osBuild: deps.machine.osBuild)?.highestGrantedHeadroom
            .map { FactorMath.headroomMargin * $0 }
    }

    /// Learns the grant of a reading taken while this display boosts (DESIGN.md §12.1's "macOS allowed up to …").
    func noteGrant(_ headroom: Double) {
        deps.cache.learnGrantedHeadroom(headroom, for: key, osBuild: deps.machine.osBuild)
    }
}
