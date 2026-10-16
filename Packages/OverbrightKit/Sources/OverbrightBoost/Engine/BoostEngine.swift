// OverbrightBoost/Engine/BoostEngine.swift — the engine behind `BoostControl`. ARCHITECTURE.md §4.1, §4.9, §10.6.
// Seeded by WP0a with the fixed initializers (§10.0); body by WP4: master state, the policy loop over the injected
// reducer, one `DisplayController` per display, synchronous shield delivery, pause and auto-off, the HUD's
// `lastChange`, the low-level confirmation, and the self-test, calibration and rescue entry points through WP5's seams.
// This file holds the state, the initializers, the lifecycle and status publication; requests live in
// `BoostEngine+Control.swift`, the policy loop and HUD changes in `+Policy`, events and deadlines in `+Events`, the
// instruments in `+Instruments`. MainActor.
import CoreGraphics
import Foundation
import Observation
import OverbrightCore
import OverbrightPolicy

/// The per-display boost engine (`services.boost`) and the last service to start, first to stop (D7, D23).
@Observable public final class BoostEngine: BoostControl, ServiceLifecycle {
    /// What the UI, the menu, intents and diagnostics read.
    public private(set) var status: BoostStatus = .initial

    @ObservationIgnored let settings: SettingsStore
    @ObservationIgnored let machine: MachineIdentity
    @ObservationIgnored let time: any TimeSource
    @ObservationIgnored let journal: any DiagnosticsJournal
    @ObservationIgnored let ownEDRSurfaces: OwnEDRSurfaces
    @ObservationIgnored let displays: any DisplayDirectory
    @ObservationIgnored let signals: any SystemSignals
    @ObservationIgnored let gamma: any GammaPort
    @ObservationIgnored let headroom: any HeadroomPort
    @ObservationIgnored let triggers: any TriggerFactory
    @ObservationIgnored let conflicts: any ConflictProbe
    @ObservationIgnored let reduce: (PolicyInput) -> PolicyDecision

    /// The baselines to restore and the hang epoch. The composition root hands it, with `writer`, to WP5's signal
    /// handlers; the engine's hang watchdog uses the same pair.
    @ObservationIgnored public let ledger: SafetyLedger
    /// The only path to `GammaPort.write` (§4.5 invariant 3).
    @ObservationIgnored public let writer: TableWriter
    /// The learned rungs and the lowest ready headroom (§4.7); in memory until `useStrategyCache(at:)`.
    @ObservationIgnored public let strategyCache = StrategyCache()
    @ObservationIgnored let watchdog: HangWatchdog
    /// Tests switch the hang watchdog off and simulate it (the WP5 body runs a real timer).
    @ObservationIgnored var watchdogEnabled = true
    /// `--off` wins over "Launch and turn on" (§3.8); tests replace it.
    @ObservationIgnored var launchArguments = LaunchArguments.current
    /// The display under the pointer for Brighter / Less Bright (tests replace it).
    @ObservationIgnored var pointerDisplay: @MainActor ([DisplayFacts]) -> DisplayKey? = BoostEngine.displayUnderPointer
    @ObservationIgnored var strategyCacheFile: URL?

    // MARK: State

    @ObservationIgnored var controllers: [DisplayKey: DisplayController] = [:]
    @ObservationIgnored var isMasterOn = false
    @ObservationIgnored var isStarted = false
    @ObservationIgnored var isReady = false
    @ObservationIgnored var lastDecision: PolicyDecision?
    @ObservationIgnored var reducePending = false
    @ObservationIgnored var isApplying = false
    @ObservationIgnored var continued: [String: Int32] = [:]
    @ObservationIgnored var changeSequence: UInt64 = 0
    @ObservationIgnored var lastChange: LevelChange?
    @ObservationIgnored var pendingLowLevel: LowLevelConfirmation?
    @ObservationIgnored var dimMemory: [DisplayKey: LevelPosition] = [:]
    @ObservationIgnored var linkedDimMemory: LevelPosition?
    @ObservationIgnored var autoOffAt: Date?
    @ObservationIgnored var armedPauseDeadline: Date?
    @ObservationIgnored var armedScheduleBoundary: Date?
    @ObservationIgnored var lastFocus: FocusDirective = .leaveAlone
    @ObservationIgnored var lastDirectoryGeneration: Int?
    @ObservationIgnored let pauseSlot = TaskSlot()
    @ObservationIgnored let autoOffSlot = TaskSlot()
    @ObservationIgnored let lowLevelSlot = TaskSlot()
    @ObservationIgnored let scheduleSlot = TaskSlot()
    @ObservationIgnored let preparingSlot = TaskSlot()
    @ObservationIgnored var observers: [ObservationToken] = []
    @ObservationIgnored var instrumentHold = false
    /// The running calibration (kept until its `onEnd`); the master stays off meanwhile.
    @ObservationIgnored var calibrationSession: CalibrationController?
    @ObservationIgnored var boostSourcesActive = false
    @ObservationIgnored var watchdogActive = false

    /// The engine over explicit dependencies: what the composition root uses, because the services hub needs the
    /// engine before it exists. Constructing it does no I/O; `start()` does.
    /// - Parameter reduce: the policy reducer (WP4's tests inject TestSupport's `ReferenceReducer`).
    public init(settings: SettingsStore, machine: MachineIdentity, time: any TimeSource, journal: any DiagnosticsJournal,
                ownEDRSurfaces: OwnEDRSurfaces, displays: any DisplayDirectory, signals: any SystemSignals,
                gamma: any GammaPort, headroom: any HeadroomPort, triggers: any TriggerFactory,
                conflicts: any ConflictProbe,
                reduce: @escaping (PolicyInput) -> PolicyDecision = BoostPolicy.reduce) {
        self.settings = settings; self.machine = machine; self.time = time; self.journal = journal
        self.ownEDRSurfaces = ownEDRSurfaces; self.displays = displays; self.signals = signals
        self.gamma = gamma; self.headroom = headroom; self.triggers = triggers; self.conflicts = conflicts
        self.reduce = reduce
        let ledger = SafetyLedger()
        let writer = TableWriter(gamma: gamma, ledger: ledger, time: time, journal: journal)
        self.ledger = ledger
        self.writer = writer
        self.watchdog = HangWatchdog(writer: writer, ledger: ledger, journal: journal)
    }

    /// The engine over the ports of an existing hub (tests and previews: `.preview(fixture:)`); the hub's own `boost`
    /// is not used. The signature of ARCHITECTURE.md §10.0.
    public convenience init(services: OverbrightServices, gamma: any GammaPort, headroom: any HeadroomPort,
                            triggers: any TriggerFactory, conflicts: any ConflictProbe,
                            reduce: @escaping (PolicyInput) -> PolicyDecision = BoostPolicy.reduce) {
        self.init(settings: services.settings, machine: services.machine, time: services.time,
                  journal: services.journal, ownEDRSurfaces: services.ownEDRSurfaces, displays: services.displays,
                  signals: services.signals, gamma: gamma, headroom: headroom, triggers: triggers,
                  conflicts: conflicts, reduce: reduce)
    }

    /// Keeps the strategy cache in `url` (`AppPaths.caches/strategy-cache.json`, §8.2); call before `start()`.
    public func useStrategyCache(at url: URL) { strategyCacheFile = url }

    /// Advanced ▸ "Forget learned methods": every learned rung and headroom goes (§4.7).
    public func forgetLearnedStrategies() { strategyCache.forget() }

    /// `BoostControl.forgetLearnedMethods()` (the contract-lane requirement Settings ▸ Advanced calls): the same.
    public func forgetLearnedMethods() {
        forgetLearnedStrategies()
        journal.record("strategies.forgotten", display: nil, time: time)
    }

    // MARK: ServiceLifecycle

    /// "boost".
    public var serviceName: String { "boost" }

    /// Observes settings, the snapshot, the directory and own EDR surfaces; follows the launch behaviour (`--off`
    /// wins); runs the first reduction and becomes ready. The launch check has already run (the shell's order, §7.4).
    public func start() async {
        guard !isStarted else { return }
        if let strategyCacheFile { await strategyCache.attach(file: JSONDocumentFile(url: strategyCacheFile)) }
        isStarted = true
        syncControllers(reconfigured: false)
        lastFocus = signals.snapshot.focus
        observers.append(signals.addEventObserver { [weak self] event in self?.handle(event) })
        observers.append(observe({ [weak self] in self?.observedInputs() }, onChange: { [weak self] _ in
            self?.inputsChanged()
        }))
        if settings[GeneralSettings.launchBehavior] == .launchAndEnable, !launchArguments.startsOff {
            turnOn(source: .launch)
        }
        reduceNow()
        isReady = true
        publish()
    }

    /// The ramped stop (Boost stops first, §7.4): every display ramps to 1, writes its baseline and removes its
    /// trigger; then nothing runs.
    public func stop() async {
        guard isStarted else { return }
        turnOff()
        let kind: RampPlanner.Kind = signals.snapshot.reduceMotion ? .reduceMotion : .standard
        let all = Array(controllers.values)
        for controller in all { controller.beginStop(kind: kind) }
        for controller in all { await controller.waitUntilSettled() }
        finishStop()
    }

    /// Synchronous fallback from `applicationWillTerminate`: no ramp, baselines written at once.
    public func stopNow() {
        turnOff()
        for controller in controllers.values { controller.stopNow() }
        ledger.withLock { state in
            writer.writeBaselines(fromLedger: state)
            state.entries = [:]
        }
        finishStop()
    }

    private func finishStop() {
        for token in observers { token.cancel() }
        observers = []
        isStarted = false
        reducePending = false
        updateAggregates()
        publish()
    }

    // MARK: Status

    /// Tasks alive in the engine and its controllers (zero while off and not dimmed, §4.5 invariant 4).
    var activeTaskCount: Int {
        [pauseSlot, autoOffSlot, lowLevelSlot, scheduleSlot, preparingSlot].filter(\.isRunning).count
            + controllers.values.map(\.activeTaskCount).reduce(0, +)
    }

    /// Republishes `status` (only when it changed).
    func publish() {
        guard !isApplying else { return }
        let now = time.wallClock
        let pausedUntil = settings[AutomationSettings.pausedUntil].flatMap { $0 > now ? $0 : nil }
        let statuses = displays.displays.compactMap { controllers[$0.ref.key]?.status() }
        let next = BoostStatus(isOn: isMasterOn, isReady: isReady, pausedUntil: pausedUntil, autoOffAt: autoOffAt,
                               displays: statuses, banner: lastDecision?.banner, symbol: symbol(),
                               lastChange: lastChange, pendingLowLevel: pendingLowLevel)
        if next != status { status = next }
    }

    /// The reducer's symbol, with `preparing` while a display that should boost is arming or gating and none is
    /// boosted yet (§6.4: the reducer cannot see phases).
    func symbol() -> StatusSymbolState {
        guard isMasterOn else { return .off }
        let symbol = lastDecision?.symbol ?? .on
        guard symbol == .on || symbol == .preparing else { return symbol }
        return isPreparingNow ? .preparing : .on
    }

    /// A display that should boost is arming or gating and none is ramping or boosted.
    var isPreparingNow: Bool {
        let boosting = controllers.values.filter { $0.targetGain != nil }
        return boosting.contains(where: \.isPreparing)
            && !boosting.contains { $0.phase == .boosted || $0.phase == .ramping }
    }

    /// A controller changed: aggregates, status, and a re-reduction when its feedback changed.
    func controllerChanged(needsReduction: Bool) {
        guard !isApplying else {
            if needsReduction { scheduleReduce() }
            return
        }
        updateAggregates()
        publish()
        if needsReduction { scheduleReduce() }
    }

    /// The boost-only signal sources, the hang watchdog and the boost marker follow the displays' state.
    func updateAggregates() {
        let all = Array(controllers.values)
        let active = isStarted && all.contains(where: \.isActive)
        if active != boostSourcesActive {
            boostSourcesActive = active
            signals.setBoostActive(active)
        }
        let scaled = all.filter(\.isScaledOrDimmed)
        let anyScaled = !scaled.isEmpty
        if anyScaled != watchdogActive {
            watchdogActive = anyScaled
            if watchdogEnabled { watchdog.setActive(anyScaled) }
        }
        updateMarker(scaled)
        if watchdogEnabled, watchdog.consumeFiredFlag() {
            journal.record("hang.fired", display: nil, time: time)
            for controller in all where controller.isScaledOrDimmed && controller.epochStamp != ledger.hangEpoch {
                controller.recoverFromHang()
            }
        }
    }

    /// The boost marker (D7): present while any display is scaled or dimmed, with the displays and the largest factor.
    func updateMarker(_ scaled: [DisplayController]) {
        let current = settings[EngineRecords.boostMarker]
        let keys = scaled.map(\.key).sorted()
        guard !keys.isEmpty else {
            if current != nil { settings[EngineRecords.boostMarker] = nil }
            return
        }
        let maxFactor = scaled.map(\.appliedFactor).max() ?? 1
        if let current, current.displays == keys, maxFactor <= current.maxFactor + 0.05 { return }
        settings[EngineRecords.boostMarker] = BoostMarker(since: current?.since ?? time.wallClock, displays: keys,
                                                          maxFactor: max(maxFactor, current?.maxFactor ?? 0))
    }

    /// The display under the mouse pointer (a read-only CoreGraphics query), else nil.
    static func displayUnderPointer(_ displays: [DisplayFacts]) -> DisplayKey? {
        guard let location = CGEvent(source: nil)?.location else { return nil }
        return displays.first { CGDisplayBounds($0.ref.id).contains(location) }?.ref.key
    }
}
