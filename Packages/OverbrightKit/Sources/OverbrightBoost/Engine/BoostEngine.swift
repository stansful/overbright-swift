// OverbrightBoost/Engine/BoostEngine.swift — the engine behind `BoostControl`. ARCHITECTURE.md §4.1, §4.9, §10.6.
// Seeded by WP0a with the fixed initializers (§10.0); owned by WP4, which writes the body (master state, the policy
// loop over the injected reducer, one `DisplayController` per display, shields, pause and auto-off, the HUD's
// `lastChange`). The WP0a body publishes every display idle and changes nothing: it holds no `TableWriter`, opens no
// trigger and starts no task, so the app cannot touch a display before WP4 lands.
import Foundation
import Observation
import OverbrightCore
import OverbrightPolicy

/// The per-display boost engine (`services.boost`) and the last service to start, first to stop (D7, D23).
@Observable public final class BoostEngine: BoostControl, ServiceLifecycle {
    /// What the UI, the menu, intents and diagnostics read.
    public private(set) var status: BoostStatus = .initial

    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let machine: MachineIdentity
    @ObservationIgnored private let time: any TimeSource
    @ObservationIgnored private let journal: any DiagnosticsJournal
    @ObservationIgnored private let ownEDRSurfaces: OwnEDRSurfaces
    @ObservationIgnored private let displays: any DisplayDirectory
    @ObservationIgnored private let signals: any SystemSignals
    @ObservationIgnored private let gamma: any GammaPort
    @ObservationIgnored private let headroom: any HeadroomPort
    @ObservationIgnored private let triggers: any TriggerFactory
    @ObservationIgnored private let conflicts: any ConflictProbe
    @ObservationIgnored private let reduce: (PolicyInput) -> PolicyDecision

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

    // MARK: ServiceLifecycle

    /// "boost".
    public var serviceName: String { "boost" }

    /// WP0a seed: publishes every online display idle at Standard and becomes ready.
    public func start() async {
        status = BoostStatus(isOn: false, isReady: true, pausedUntil: nil, autoOffAt: nil,
                             displays: displays.displays.map(Self.idleStatus), banner: nil, symbol: .off)
    }

    /// WP0a seed: nothing is scaled, so nothing to ramp down.
    public func stop() async {}

    /// WP0a seed: nothing is scaled, so no baseline to write.
    public func stopNow() {}

    // MARK: BoostControl (WP0a seed: requests change nothing)

    /// WP4.
    public func setOn(_ on: Bool, source: ControlSource) { _ = (on, source) }
    /// WP4.
    public func toggle(source: ControlSource) { _ = source }
    /// WP4.
    public func setLevel(_ level: LevelPosition, for display: DisplayKey?, source: ControlSource) {
        _ = (level, display, source)
    }
    /// WP4.
    public func setExtraBrightness(_ request: ExtraBrightnessRequest, for display: DisplayKey?, source: ControlSource) {
        _ = (request, display, source)
    }
    /// WP4.
    public func setDimLight(_ light: Double, for display: DisplayKey?, source: ControlSource) {
        _ = (light, display, source)
    }
    /// WP4.
    public func step(_ direction: StepDirection, source: ControlSource) { _ = (direction, source) }
    /// WP4.
    public func toggleDim(source: ControlSource) { _ = source }
    /// WP4.
    public func returnToStandard(source: ControlSource) { _ = source }
    /// WP4.
    public func keepLowLevel() {}
    /// WP4.
    public func revertLowLevel() {}
    /// WP4.
    public func pause(until deadline: Date?, source: ControlSource) { _ = (deadline, source) }
    /// WP4.
    public func resume(source: ControlSource) { _ = source }
    /// WP4.
    public func continueAnyway(_ app: ConflictingApp) { _ = app }
    /// WP4.
    public func retry(_ display: DisplayKey) { _ = display }
    /// WP4/WP5: an empty report.
    public func runSelfTest(_ options: SelfTestOptions) async -> SelfTestReport {
        _ = options
        return SelfTestReport(startedAt: time.wallClock, machine: machine, appVersion: AppInfo.current().version,
                              displays: [:], journal: [])
    }
    /// WP4/WP5: no calibration yet.
    public func beginCalibration(of display: DisplayKey) -> (any CalibrationSession)? {
        _ = display
        return nil
    }
    /// WP4/WP5: does nothing.
    public func rescueDisplayColors() async -> RescueOutcome { .alreadyNeutral }

    private static func idleStatus(_ facts: DisplayFacts) -> DisplayStatus {
        DisplayStatus(key: facts.ref.key, name: facts.name, phase: .idle, decision: nil, appliedGain: 1,
                      appliedFactor: 1, mechanism: .table, strategy: nil, lastReading: nil, sdrWhite: nil)
    }
}
