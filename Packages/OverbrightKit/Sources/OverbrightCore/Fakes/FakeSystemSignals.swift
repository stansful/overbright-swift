// OverbrightCore/Fakes/FakeSystemSignals.swift — SystemSignals with a settable snapshot. ARCHITECTURE.md §3.9, §4.1, §7.1.
import Observation

/// A `SystemSignals` whose snapshot tests set directly and whose events `emit(_:)` delivers synchronously, in
/// registration order, like the real one (§4.1). Records `setBoostActive`, `refreshPowerNow` and `setFocusDirective`.
@MainActor @Observable public final class FakeSystemSignals: SystemSignals {
    /// The snapshot (settable).
    public var snapshot: SystemSnapshot
    /// What `refreshPowerNow()` reads into `snapshot.power`; nil leaves it as it is.
    public var powerOnRefresh: PowerState?
    /// Every `setBoostActive(_:)` value, in order.
    public private(set) var boostActiveCalls: [Bool] = []
    /// Number of `refreshPowerNow()` calls.
    public private(set) var refreshPowerNowCount = 0
    /// Every `setFocusDirective(_:)` value, in order.
    public private(set) var focusDirectives: [FocusDirective] = []
    @ObservationIgnored private var observers: [(id: UInt64, handler: @MainActor (SystemEvent) -> Void)] = []
    @ObservationIgnored private var lastID: UInt64 = 0

    /// Quiet, unlocked, on the adapter with a full battery by default.
    public init(snapshot: SystemSnapshot = SystemSnapshot(power: PowerState(source: .adapter, batteryPercent: 100,
                                                                             isLowPowerMode: false))) {
        self.snapshot = snapshot
    }

    /// Number of registered event observers.
    public var observerCount: Int { observers.count }

    /// Registers `handler` until the token is cancelled or released.
    public func addEventObserver(_ handler: @escaping @MainActor (SystemEvent) -> Void) -> ObservationToken {
        lastID += 1
        let id = lastID
        observers.append((id, handler))
        return ObservationToken { [weak self] in self?.observers.removeAll { $0.id == id } }
    }

    /// Delivers `event` to every observer before returning (shield events must be neutral when this returns).
    public func emit(_ event: SystemEvent) {
        for observer in observers { observer.handler(event) }
    }
    /// Delivers `events` in order.
    public func emit(_ events: [SystemEvent]) { for event in events { emit(event) } }

    /// Records the call.
    public func setBoostActive(_ active: Bool) {
        boostActiveCalls.append(active)
        if active { refreshPowerNow() }
    }
    /// Records the call and applies `powerOnRefresh`.
    public func refreshPowerNow() {
        refreshPowerNowCount += 1
        if let powerOnRefresh { snapshot.power = powerOnRefresh }
    }
    /// Records the directive and puts it in the snapshot.
    public func setFocusDirective(_ directive: FocusDirective) {
        focusDirectives.append(directive)
        snapshot.focus = directive
    }

    // MARK: Scripted launches and terminations

    /// A conflicting app launches: it joins `snapshot.conflicts` (and `probe`'s running list), then `.appLaunched`.
    public func appLaunched(_ app: ConflictingApp, probe: FakeConflictProbe? = nil) {
        snapshot.conflicts.append(app)
        probe?.running.append(app)
        emit(.appLaunched(bundleID: app.bundleID))
    }
    /// A conflicting app quits: it leaves both lists, then `.appTerminated`.
    public func appTerminated(_ app: ConflictingApp, probe: FakeConflictProbe? = nil) {
        snapshot.conflicts.removeAll { $0.processID == app.processID }
        probe?.running.removeAll { $0.processID == app.processID }
        emit(.appTerminated(bundleID: app.bundleID, processID: app.processID))
    }
}
