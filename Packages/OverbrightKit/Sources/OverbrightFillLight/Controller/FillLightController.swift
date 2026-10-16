// OverbrightFillLight/Controller/FillLightController.swift — the Fill Light service. ARCHITECTURE.md §10.9, §3.6
// (`FillLightControl`, `ServiceLifecycle`), §3.9 (`OwnEDRSurfaces`), §3.11 ("FillLight → system"), §7.1, §7.6, D6, D12,
// D22; DESIGN.md §7.7, §11, §12.9 (announcements).
//
// Thread: main actor only. Settings, the signals snapshot and the display directory arrive through `observe` (main
// actor); system events through `SystemSignals.addEventObserver` (delivered on main, synchronously); the rule's
// deadline and the headroom settle reads are stored tasks sleeping on the injected `TimeSource` (no repeating timer).
// Zero work while off: no surface, no event observer, no task and no headroom read unless the light is on or the
// camera rule has a deadline pending.
import CoreGraphics
import Foundation
import Observation
import OverbrightCore
import os

private let log = Log.logger(.fillLight)

/// The Fill Light (`services.fillLight`): a glowing frame around one display for video calls (DESIGN.md §11).
///
/// It follows the `fillLight.*` settings live, picks the chosen display (else the built-in, else the main display),
/// shows its frame through a `FillLightSurfaceFactory`, asks for EDR headroom where the display has extra range and
/// registers that display with `OwnEDRSurfaces` while it does, so Boost counts the range as already in use (D6).
/// The camera rule turns it on and off with the camera (`FillLightRule`).
@MainActor @Observable public final class FillLightController: FillLightControl, ServiceLifecycle {
    /// The light should show (the user turned it on, or the camera rule did).
    public private(set) var isOn = false
    /// The camera rule turned it on.
    public private(set) var isAutomatic = false

    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let displays: any DisplayDirectory
    @ObservationIgnored private let headroom: any HeadroomPort
    @ObservationIgnored private let signals: any SystemSignals
    @ObservationIgnored private let ownEDRSurfaces: OwnEDRSurfaces
    @ObservationIgnored private let time: any TimeSource
    @ObservationIgnored private let journal: any DiagnosticsJournal
    @ObservationIgnored private let announcer: Announcer
    @ObservationIgnored private let factory: any FillLightSurfaceFactory
    @ObservationIgnored private let mainDisplayID: @MainActor () -> CGDirectDisplayID

    @ObservationIgnored private var rule: FillLightRule
    @ObservationIgnored private var isRunning = false
    @ObservationIgnored private var observations: [ObservationToken] = []
    @ObservationIgnored private var eventToken: ObservationToken?
    @ObservationIgnored private var surface: (any FillLightSurface)?
    @ObservationIgnored private var appliedStyle: FillLightStyle?
    @ObservationIgnored private var hold: (key: DisplayKey, token: ObservationToken)?
    @ObservationIgnored private var removedDisplays: Set<CGDirectDisplayID> = []
    @ObservationIgnored private var lastFailure: DisplayRef?
    @ObservationIgnored private var ruleTask: Task<Void, Never>?
    @ObservationIgnored private var ruleTaskDeadline: MonotonicInstant?
    @ObservationIgnored private var settleTask: Task<Void, Never>?

    /// A controller over the hub's ports. Constructing it does nothing; `start()` begins observing.
    /// - Parameters:
    ///   - surfaces: `SystemFillLightSurfaces()` in the app (its SDR stand-in under `--qa-simulate`), a fake in tests.
    ///   - cameraTiming: the camera rule's delays; `.standard` (1 s on, 3 s off) unless Signals already debounces
    ///     `isCameraInUse` by the same amounts.
    ///   - mainDisplayID: the display with the menu bar (the fallback without a built-in display).
    public init(settings: SettingsStore, displays: any DisplayDirectory, headroom: any HeadroomPort,
                signals: any SystemSignals, ownEDRSurfaces: OwnEDRSurfaces, time: any TimeSource,
                journal: any DiagnosticsJournal, announcer: Announcer, surfaces: any FillLightSurfaceFactory,
                cameraTiming: FillLightRule.Timing = .standard,
                mainDisplayID: @escaping @MainActor () -> CGDirectDisplayID = { CGMainDisplayID() }) {
        self.settings = settings; self.displays = displays; self.headroom = headroom; self.signals = signals
        self.ownEDRSurfaces = ownEDRSurfaces; self.time = time; self.journal = journal; self.announcer = announcer
        self.factory = surfaces; self.mainDisplayID = mainDisplayID
        rule = FillLightRule(timing: cameraTiming)
    }

    isolated deinit { stopNow() }

    /// The display the frame shows on now (nil while off or while no display can host it).
    public var currentDisplay: DisplayKey? { surface?.display.key }

    /// The style the frame shows now (nil while it shows nothing).
    public var currentStyle: FillLightStyle? { surface == nil ? nil : appliedStyle }

    // MARK: FillLightControl

    /// Turns the light on or off by hand. Off while a followed camera runs keeps it off until the camera stops.
    public func setOn(_ on: Bool, source: ControlSource) {
        updateRule(source: source) { $0.setManually(on) }
    }

    // MARK: ServiceLifecycle

    /// "FillLight".
    public var serviceName: String { "FillLight" }

    /// Starts following settings, the camera signal and the displays, and shows the frame if the light is on.
    public func start() async {
        guard !isRunning else { return }
        isRunning = true
        let values = FillLightSettingsValues.read(settings)
        let running = signals.snapshot.isCameraInUse
        observations = [
            observe({ [settings] in FillLightSettingsValues.read(settings) }) { [weak self] in self?.settingsChanged($0) },
            observe({ [signals] in signals.snapshot.isCameraInUse }) { [weak self] in self?.cameraChanged($0) },
            observe({ [signals] in signals.snapshot.fullScreenDisplays }) { [weak self] _ in self?.reconcile() },
            observe({ [displays] in displays.generation }) { [weak self] _ in self?.displaysChanged() },
        ]
        updateRule(source: nil) { [now = time.now] next in
            next.setFollowsCamera(values.followsCamera, now: now)
            next.cameraChanged(running: running, now: now)
        }
    }

    /// Removes the frame and stops observing (nothing to ramp: the frame is our own content, not a table).
    public func stop() async { stopNow() }

    /// Removes the frame at once and stops observing.
    public func stopNow() {
        isRunning = false
        for token in observations { token.cancel() }
        observations = []
        ruleTask?.cancel()
        ruleTask = nil
        ruleTaskDeadline = nil
        hideAll()
    }

    // MARK: Inputs

    private func settingsChanged(_ values: FillLightSettingsValues) {
        if values.followsCamera != rule.followsCamera {
            updateRule(source: .settings) { [now = time.now] in $0.setFollowsCamera(values.followsCamera, now: now) }
        } else {
            reconcile()
        }
    }

    private func cameraChanged(_ running: Bool) {
        updateRule(source: nil) { [now = time.now] in $0.cameraChanged(running: running, now: now) }
    }

    private func displaysChanged() {
        removedDisplays = []
        lastFailure = nil
        reconcile()
    }

    /// Events matter only while the frame shows (registered then, cancelled when it goes).
    private func handle(_ event: SystemEvent) {
        switch event {
        case .displayRemoved(let id):
            // At once, before the directory's next generation (§4.3, §7.1).
            removedDisplays.insert(id)
            if let surface, surface.display.id == id {
                record("fillLight.displayRemoved", display: surface.display.key)
                removeSurface()
            }
        case .screenParametersChanged, .displaysReconfigured:
            lastFailure = nil
            surface?.refresh()
            reconcile()
        case .didWake, .screensDidWake, .unlocked, .screensaverStopped, .sessionBecameActive:
            surface?.refresh()
        default:
            break
        }
    }

    private func surfaceMoved(_ moved: any FillLightSurface, to id: CGDirectDisplayID?) {
        guard moved === surface, id != moved.display.id else { return }
        record("fillLight.leftDisplay", display: moved.display.key)
        removeSurface()   // never light another display; the next reconfiguration or screen change re-places it
    }

    // MARK: State

    /// Changes the rule, publishes `isOn` and `isAutomatic`, announces an on/off change (`source` nil: the camera
    /// rule), then makes the screen match and re-arms the rule's deadline.
    private func updateRule(source: ControlSource?, _ change: (inout FillLightRule) -> Void) {
        let wasOn = rule.isOn
        change(&rule)
        if isOn != rule.isOn { isOn = rule.isOn }
        if isAutomatic != rule.isAutomatic { isAutomatic = rule.isAutomatic }
        if wasOn != rule.isOn { stateChanged(on: rule.isOn, source: source) }
        reconcile()
        scheduleRuleDeadline()
    }

    private func stateChanged(on: Bool, source: ControlSource?) {
        let by = source?.rawValue ?? "camera"
        log.info("fill light \(on ? "on" : "off", privacy: .public) by \(by, privacy: .public)")
        record(on ? "fillLight.on" : "fillLight.off", values: ["automatic": source == nil ? 1 : 0])
        let text = on
            ? String(localized: "Fill Light on", bundle: .module, comment: "VoiceOver: announcement when Fill Light turns on")
            : String(localized: "Fill Light off", bundle: .module, comment: "VoiceOver: announcement when Fill Light turns off")
        announcer.announce(text, kind: source == nil ? .alert : .feedback)
    }

    /// Makes the screen match the state: the frame on the target display with the current style, the
    /// `OwnEDRSurfaces` hold while it asks for headroom, nothing at all while off or stopped.
    private func reconcile() {
        guard isRunning, rule.isOn else {
            hideAll()
            return
        }
        if eventToken == nil {
            eventToken = signals.addEventObserver { [weak self] in self?.handle($0) }
        }
        let values = FillLightSettingsValues.read(settings)
        guard let target = targetDisplay(values) else {
            removeSurface()
            return
        }
        if let current = surface, current.display != target { removeSurface() }
        guard let shown = surface ?? makeSurface(on: target) else { return }
        let style = FillLightStyle.make(width: values.width, warmth: values.warmth, brightness: values.brightness,
                                        reading: headroom.reading(for: target), rendering: shown.rendering,
                                        reachesTop: signals.snapshot.fullScreenDisplays.contains(target.key))
        if style != appliedStyle {
            let requestChanged = style.headroomRequest != appliedStyle?.headroomRequest
            appliedStyle = style
            shown.apply(style)
            guard shown === surface else { return }   // AppKit moved it off its display while ordering it in
            if requestChanged {
                record("fillLight.shown", display: target.key,
                       values: ["value": style.value, "request": style.headroomRequest ?? 0,
                                "rendering": shown.rendering.journalCode])
                if style.headroomRequest != nil { scheduleSettle() } else { cancelSettle() }
            }
        }
        setHold(style.headroomRequest == nil ? nil : target.key)
    }

    /// The chosen display if it can host the frame, else the built-in display, else the main display, else the first.
    /// Hardware-mirror members have no screen of their own; a display just removed is skipped until the directory
    /// catches up.
    private func targetDisplay(_ values: FillLightSettingsValues) -> DisplayRef? {
        let candidates = displays.displays.filter { !$0.isMirrored && !removedDisplays.contains($0.ref.id) }
        if let key = values.display, let chosen = candidates.first(where: { $0.ref.key == key }) { return chosen.ref }
        if let builtIn = candidates.first(where: \.isBuiltIn) { return builtIn.ref }
        let main = mainDisplayID()
        return (candidates.first { $0.ref.id == main } ?? candidates.first)?.ref
    }

    private func makeSurface(on target: DisplayRef) -> (any FillLightSurface)? {
        do {
            let made = try factory.makeSurface(on: target)
            made.onScreenChange = { [weak self, weak made] id in
                guard let self, let made else { return }
                self.surfaceMoved(made, to: id)
            }
            surface = made
            lastFailure = nil
            return made
        } catch {
            if lastFailure != target {
                lastFailure = target
                log.error("fill light: no surface on display \(target.id, privacy: .public): \(String(describing: error), privacy: .public)")
                record("fillLight.surfaceFailed", display: target.key)
            }
            setHold(nil)
            return nil
        }
    }

    private func removeSurface() {
        cancelSettle()
        if let surface {
            surface.onScreenChange = nil
            surface.remove()
        }
        surface = nil
        appliedStyle = nil
        setHold(nil)
    }

    private func hideAll() {
        removeSurface()
        eventToken?.cancel()
        eventToken = nil
    }

    private func setHold(_ key: DisplayKey?) {
        guard hold?.key != key else { return }
        hold?.token.cancel()
        hold = key.map { ($0, ownEDRSurfaces.hold($0)) }
    }

    // MARK: Deadlines

    private func scheduleRuleDeadline() {
        let deadline = isRunning ? rule.nextDeadline : nil
        guard deadline != ruleTaskDeadline else { return }
        ruleTask?.cancel()
        ruleTask = nil
        ruleTaskDeadline = deadline
        guard let deadline else { return }
        ruleTask = Task { [weak self, time] in
            do { try await time.sleep(for: deadline - time.now) } catch { return }
            guard !Task.isCancelled, let self else { return }
            self.ruleTaskDeadline = nil
            self.updateRule(source: nil) { [now = self.time.now] in $0.advance(to: now) }
        }
    }

    /// Re-reads headroom a few times while macOS raises the grant (`FillLightTiming.headroomSettleReads`).
    private func scheduleSettle() {
        settleTask?.cancel()
        let offsets = FillLightTiming.headroomSettleReads
        settleTask = Task { [weak self, time] in
            var elapsed: Duration = .zero
            for offset in offsets {
                do { try await time.sleep(for: offset - elapsed) } catch { return }
                elapsed = offset
                guard !Task.isCancelled, let self else { return }
                self.reconcile()
            }
        }
    }

    private func cancelSettle() {
        settleTask?.cancel()
        settleTask = nil
    }

    // MARK: Journal

    private func record(_ code: String, display: DisplayKey? = nil, values: [String: Double] = [:]) {
        journal.record(JournalEvent(seconds: time.now.sinceOrigin.timeInterval, category: LogCategory.fillLight.rawValue,
                                    display: display?.rawValue, code: code, values: values))
    }
}
