// OverbrightCore/Fakes/ScriptedHeadroom.swift — a HeadroomPort that follows a script over a TimeSource.
// ARCHITECTURE.md §3.9, §4.3, D6.

/// A `HeadroomPort` whose readings follow each display's `HeadroomScript` over a `TimeSource` (normally a
/// `ManualTimeSource`): idle H, a pre-held value that can leave, and the grant that requests from `FakeTriggerFactory`
/// (triggers and overlays) reach after the scripted delay and ramp. Tests drop or move H with `setOverride` (a lock
/// shield) and `setGrant(_:for:over:)` (thermal limits, the brightness keys moving H monotonically).
@MainActor public final class ScriptedHeadroom: HeadroomPort {
    private struct Request {
        let strategy: TriggerStrategy?
        let presentedAt: MonotonicInstant
    }
    private struct GrantChange {
        let from: Double
        let start: MonotonicInstant
        let duration: Duration
    }
    private struct State {
        var script: HeadroomScript
        var start: MonotonicInstant
        var requests: [UInt64: Request] = [:]
        var override: Double?
        var grantChange: GrantChange?
    }

    /// The clock the script runs on.
    public let time: any TimeSource
    private var states: [DisplayKey: State] = [:]
    /// Number of `reading(for:)` calls (tests check that nothing polls while off).
    public private(set) var readCount = 0

    /// Scripts by display, all starting now.
    public init(time: any TimeSource, scripts: [DisplayKey: HeadroomScript] = [:]) {
        self.time = time
        let now = time.now
        for (key, script) in scripts { states[key] = State(script: script, start: now) }
    }

    /// The scripts of `fixture`'s displays.
    public convenience init(fixture: DisplayFixture, time: any TimeSource) {
        self.init(time: time, scripts: Dictionary(uniqueKeysWithValues: fixture.displays.map { ($0.facts.ref.key, $0.headroom) }))
    }

    // MARK: HeadroomPort

    /// The scripted values now, stamped with `time.now`; nil for an unknown display or one without its own screen.
    public func reading(for display: DisplayRef) -> HeadroomReading? {
        readCount += 1
        guard let state = states[display.key], state.script.hasOwnScreen else { return nil }
        let now = time.now
        return HeadroomReading(display: display.id, current: current(state, at: now), potential: state.script.potential,
                               reference: state.script.reference, time: now)
    }

    // MARK: Script control

    /// The script of `key`.
    public func script(for key: DisplayKey) -> HeadroomScript? { states[key]?.script }
    /// Adds or replaces the script of `key` (its pre-held clock starts now).
    public func setScript(_ script: HeadroomScript, for key: DisplayKey) {
        var state = State(script: script, start: time.now)
        state.requests = states[key]?.requests ?? [:]
        states[key] = state
    }
    /// Changes the script of `key` in place (potential, reference, idle, …).
    public func update(_ key: DisplayKey, _ change: (inout HeadroomScript) -> Void) {
        guard var state = states[key] else { return }
        change(&state.script)
        states[key] = state
    }
    /// The display is gone: no more readings.
    public func removeDisplay(_ key: DisplayKey) { states[key] = nil }
    /// Pins H of `key` (nil = every display) to `value` until cleared with nil (a lock shield drops H to 1.0).
    public func setOverride(_ value: Double?, for key: DisplayKey? = nil) {
        for k in key.map({ [$0] }) ?? Array(states.keys) { states[k]?.override = value }
    }
    /// Moves the grant of `key` to `grant`, linearly over `duration` (zero = at once): thermal limits, the brightness
    /// keys (H rises as the user lowers system brightness), ambient light.
    public func setGrant(_ grant: Double, for key: DisplayKey, over duration: Duration = .zero) {
        guard var state = states[key] else { return }
        let now = time.now
        state.grantChange = GrantChange(from: grantNow(state, at: now), start: now, duration: duration)
        state.script.grant = grant
        states[key] = state
    }
    /// H of `key` now, without counting a read.
    public func currentHeadroom(of key: DisplayKey) -> Double? {
        states[key].map { current($0, at: time.now) }
    }
    /// Number of live requests (triggers and overlays with an EDR request) on `key`.
    public func requestCount(on key: DisplayKey) -> Int { states[key]?.requests.count ?? 0 }

    // MARK: Requests (FakeTriggerFactory)

    func requestStarted(_ id: UInt64, strategy: TriggerStrategy?, on key: DisplayKey) {
        guard states[key]?.requests[id] == nil else { return }
        states[key]?.requests[id] = Request(strategy: strategy, presentedAt: time.now)
    }

    func requestEnded(_ id: UInt64, on key: DisplayKey) { states[key]?.requests[id] = nil }

    // MARK: Model

    private func grantNow(_ state: State, at now: MonotonicInstant) -> Double {
        guard let change = state.grantChange, change.duration > .zero else { return state.script.grant }
        let progress = min(max((now - change.start) / change.duration, 0), 1)
        return change.from + (state.script.grant - change.from) * progress
    }

    private func current(_ state: State, at now: MonotonicInstant) -> Double {
        let script = state.script
        if let override = state.override { return override }
        var h = script.idle
        if let held = script.preHeld, script.preHeldLeavesAfter.map({ now < state.start + $0 }) ?? true {
            h = max(h, held)
        }
        let grant = grantNow(state, at: now)
        for request in state.requests.values where script.responds(to: request.strategy) {
            let moves = request.presentedAt + script.responseDelay
            guard now >= moves else { continue }
            let progress = script.rampDuration > .zero ? min((now - moves) / script.rampDuration, 1) : 1
            h = max(h, script.idle + (grant - script.idle) * progress)
        }
        return min(h, max(script.potential, 1))
    }
}
