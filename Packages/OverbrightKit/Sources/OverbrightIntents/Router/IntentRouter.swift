// OverbrightIntents/Router/IntentRouter.swift — the router behind the app target's App Intents adapters.
// ARCHITECTURE.md §3.11, §7.7, §10.0 (Intents seam), §10.10; DESIGN.md §12.8; D18.
// The no-argument initializer, `connect(boost:displays:signals:)`, one method per intent and `focus(_:)` are the WP0a
// seam. Every intent method waits for the connection and for `BoostStatus.isReady` (at most `readinessTimeout`, then
// `IntentRouterError.notReady`, "Overbright is still starting"), so an intent that launched Overbright runs after the
// launch check and the launch behaviour: a turn-on from an intent therefore overrides "Launch, keep off" (an explicit
// user action). Values are in the canonical units of DESIGN.md §1 principle 4: presets or light multipliers, dim
// light in percent of Standard. Main actor, like the engine; the adapters' `perform()` is `@MainActor` and one line.
import Foundation
import OverbrightChannel
import OverbrightCore
import os

private let log = Log.logger(.intents)

/// Routes the one-line intent adapters in `App/Intents/` to the engine. `OverbrightApp.init` creates it with no
/// arguments and registers it with `AppDependencyManager`, so an intent that launches the app can resolve it before
/// `applicationDidFinishLaunching`; the composition root connects it once the services exist.
@MainActor
public final class IntentRouter {
    /// How long an intent waits for the connection and for the engine to be ready.
    public static let readinessTimeout: Duration = .seconds(5)

    private let time: any TimeSource
    private let timeout: Duration
    private(set) var boost: (any BoostControl)?
    private(set) var displays: (any DisplayDirectory)?
    private var signals: (any SystemSignals)?
    private var pendingFocus: FocusDirective?
    /// Increases with every `focus(_:)`, so a launch-time read never overwrites a newer Focus delivery.
    private var focusSequence: UInt64 = 0
    private var waiters: [UInt64: CheckedContinuation<Void, Never>] = [:]
    private var nextWaiter: UInt64 = 0
    private var readiness: ObservationToken?

    /// The token `overbright://control?set=on` must carry (`BoostChannel.ensureToken`, written by the control's
    /// publisher). Tests replace it.
    public var expectedControlToken: () -> String? = { BoostChannel.token(in: PreferencesChannelStore.app) }

    /// True when an intent or the Focus filter asked for something before the composition root connected the router:
    /// this launch was most likely made for it, so the launch UI may stay silent (§7.6).
    public private(set) var wasRequestedBeforeConnection = false

    /// Creates an unconnected router on the system clock (the app's).
    public convenience init() { self.init(time: SystemTimeSource()) }

    /// Creates an unconnected router whose readiness wait runs on `time` (tests pass a `ManualTimeSource`).
    public init(time: any TimeSource, readinessTimeout: Duration = IntentRouter.readinessTimeout) {
        self.time = time
        self.timeout = readinessTimeout
    }

    /// Whether the composition root has connected the router.
    public var isConnected: Bool { boost != nil }

    /// Connects the router to the engine, the display directory and the Focus sink (called once, by the composition
    /// root). A Focus directive that arrived earlier is delivered now; waiting intents continue once the engine is
    /// ready.
    public func connect(boost: any BoostControl, displays: any DisplayDirectory, signals: any SystemSignals) {
        self.boost = boost; self.displays = displays; self.signals = signals
        if let directive = pendingFocus {
            pendingFocus = nil
            signals.setFocusDirective(directive)
        }
        readiness = observe({ boost.status.isReady }) { [weak self] isReady in
            if isReady { self?.resumeWaiters() }
        }
        if boost.status.isReady { resumeWaiters() }
    }

    // MARK: One method per intent (DESIGN.md §12.8)

    /// Turn Overbright On or Off.
    public func toggle() async throws { try await ready().toggle(source: .intent) }

    /// Turn On Overbright (overrides "Launch, keep off": it runs after the launch work).
    public func turnOn() async throws { try await ready().setOn(true, source: .intent) }

    /// Turn Off Overbright.
    public func turnOff() async throws { try await ready().setOn(false, source: .intent) }

    /// Set Extra Brightness: a preset or a light multiplier (at least ×1; each display stops at its own limit), for
    /// `display` or every display (nil).
    public func setExtraBrightness(_ request: ExtraBrightnessRequest, display: DisplayKey?) async throws {
        let boost = try await ready()
        try require(display, in: boost, allowing: \.allowsBoost, otherwise: .cannotBoost)
        boost.setExtraBrightness(Self.canonical(request), for: display, source: .intent)
    }

    /// Dim Displays: `percent` (2 … 99) of Standard light, for `display` or every display that can dim (nil).
    public func dim(percent: Int, display: DisplayKey?) async throws {
        let boost = try await ready()
        try require(display, in: boost, allowing: \.allowsDim, otherwise: .cannotDim)
        boost.setDimLight(Double(min(max(percent, 2), 99)) / 100, for: display, source: .intent)
    }

    /// Pause Overbright for `duration` (from now, on the wall clock the user sees).
    public func pause(for duration: Duration) async throws {
        let boost = try await ready()
        boost.pause(until: time.wallClock.addingTimeInterval(max(duration, .zero).timeInterval), source: .intent)
    }

    /// Resume Overbright.
    public func resume() async throws { try await ready().resume(source: .intent) }

    /// Get Overbright State: the engine's status (`stateReport(valueText:)` words the dialog).
    public func state() async throws -> BoostStatus { try await ready().status }

    /// Back to Standard.
    public func returnToStandard() async throws { try await ready().returnToStandard(source: .intent) }

    /// The Focus filter's directive, handed to `SystemSignals.setFocusDirective(_:)` (kept until the router is
    /// connected; Signals persists it).
    public func focus(_ directive: FocusDirective) {
        focusSequence &+= 1
        if let signals {
            signals.setFocusDirective(directive)
        } else {
            wasRequestedBeforeConnection = true
            pendingFocus = directive
        }
    }

    /// The launch-time read of the Focus filter (`OverbrightFocusFilter.current`): v1 has no extension to receive a
    /// Focus change while Overbright is quit, so the app reads the filter once at launch. A read that fails leaves the
    /// directive Signals persisted; a Focus delivery that arrives while the read runs is newer and wins.
    public func applyLaunchFocus(_ read: @MainActor () async throws -> FocusDirective) async {
        let sequence = focusSequence
        do {
            let directive = try await read()
            guard focusSequence == sequence else { return }
            focus(directive)
        } catch {
            log.info("launch focus read failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// `overbright://control?set=…` (the dormant control's hand-off, D25): `off` always, `on` only with the token the
    /// app keeps. Returns false when the request was refused; the accepted one still goes through the policy.
    @discardableResult
    public func control(on: Bool, token: String?) async throws -> Bool {
        guard URLRoute.control(on: on, token: token).accepts(token: expectedControlToken()) else {
            log.error("control route refused: set=on without the app's token")
            return false
        }
        if on { try await turnOn() } else { try await turnOff() }
        return true
    }

    // MARK: Readiness

    /// The engine once it is connected and ready; `notReady` after `timeout` (or when the waiting task is cancelled).
    func ready() async throws -> any BoostControl {
        if let boost, boost.status.isReady { return boost }
        if boost == nil { wasRequestedBeforeConnection = true }
        let id = nextWaiter
        nextWaiter &+= 1
        let timer = Task { [weak self, time, timeout] in
            do { try await time.sleep(for: timeout) } catch { return }
            self?.resumeWaiter(id)
        }
        await withTaskCancellationHandler {
            await withCheckedContinuation { waiters[id] = $0 }
        } onCancel: {
            Task { @MainActor [weak self] in self?.resumeWaiter(id) }
        }
        timer.cancel()
        guard let boost, boost.status.isReady else {
            log.error("intent gave up: Overbright not ready after \(self.timeout.timeInterval, privacy: .public) s")
            throw IntentRouterError.notReady
        }
        return boost
    }

    private func resumeWaiter(_ id: UInt64) { waiters.removeValue(forKey: id)?.resume() }

    private func resumeWaiters() {
        let continuations = waiters.values
        waiters.removeAll()
        for continuation in continuations { continuation.resume() }
    }

    // MARK: Checks

    /// `display` must be online and, when its verdict is known, allow the action; for every display (nil), at least
    /// one online display must allow it unless some verdict is not known yet (the engine then decides).
    private func require(_ display: DisplayKey?, in boost: any BoostControl, allowing allows: (DisplayVerdict) -> Bool,
                         otherwise error: IntentRouterError) throws {
        let verdicts = Dictionary(boost.status.displays.map { ($0.key, Self.knownVerdict($0)) }) { first, _ in first }
        if let display {
            guard displays?.facts(for: display) != nil else { throw IntentRouterError.displayNotConnected }
            if let verdict = verdicts[display] ?? nil, !allows(verdict) { throw error }
            return
        }
        let online = displays?.displays.map(\.ref.key) ?? []
        let known = online.map { verdicts[$0] ?? nil }
        if known.allSatisfy({ $0.map { !allows($0) } ?? false }) { throw error }
    }

    /// A display's verdict once the classifier has one (`checking` counts as not known).
    static func knownVerdict(_ status: DisplayStatus) -> DisplayVerdict? {
        guard let verdict = status.decision?.eligibility.verdict, verdict != .checking else { return nil }
        return verdict
    }

    /// The request in canonical units: a multiplier is a light gain of at least ×1 (a non-finite one is ×1).
    static func canonical(_ request: ExtraBrightnessRequest) -> ExtraBrightnessRequest {
        guard case .multiplier(let gain) = request else { return request }
        return .multiplier(gain.isFinite ? max(gain, 1) : 1)
    }
}
