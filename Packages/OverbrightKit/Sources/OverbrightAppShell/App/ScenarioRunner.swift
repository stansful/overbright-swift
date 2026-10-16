// OverbrightAppShell/App/ScenarioRunner.swift — DEBUG-only: runs a `ScenarioScript` over the simulated ports, the way
// the system would deliver it: Signals' snapshot first, then the event, synchronously (§4.1, `FakeSystemSignals`).
// ARCHITECTURE.md §8.5 (`--qa-script`), §10.15 (the QA matrix and `EndToEndScenarioTests` share it). It refuses to run
// over real ports: `Rig(shell:)` is nil unless every port it drives is a Core fake.
#if DEBUG
import Foundation
import OverbrightCore
import os

private let log = Log.logger(.app)

/// Runs scenario steps against a shell wired to the simulated ports.
final class ScenarioRunner {
    /// What a scenario drives: the hub and the fakes behind it.
    struct Rig {
        let services: OverbrightServices
        let signals: FakeSystemSignals
        let conflicts: FakeConflictProbe
        let gamma: FakeGammaPort
        let triggers: FakeTriggerFactory

        /// The rig of `shell`; nil unless its ports are the simulated ones.
        init?(shell: Shell) {
            guard shell.ports.fixture != nil, let signals = shell.ports.signals as? FakeSystemSignals,
                  let conflicts = shell.ports.conflicts as? FakeConflictProbe,
                  let gamma = shell.ports.gamma as? FakeGammaPort,
                  let triggers = shell.ports.triggers as? FakeTriggerFactory else { return nil }
            services = shell.services; self.signals = signals; self.conflicts = conflicts
            self.gamma = gamma; self.triggers = triggers
        }
    }

    private let rig: Rig
    private let wait: (Duration) async -> Void
    private let record: (StatusSummary) -> Void
    private let quit: () -> Void
    private var nextProcessID: Int32 = 90_000
    /// The summaries `dump` recorded, in order.
    private(set) var summaries: [StatusSummary] = []

    /// A runner over `rig`; `wait` passes time (real sleeps in the app, a manual clock in tests), `record` receives
    /// every `dump`, `quit` ends the app.
    init(rig: Rig, wait: @escaping (Duration) async -> Void, record: @escaping (StatusSummary) -> Void = { _ in },
         quit: @escaping () -> Void = {}) {
        self.rig = rig; self.wait = wait; self.record = record; self.quit = quit
    }

    /// Runs `steps` in order; `loop` starts them again (until the task is cancelled or a `quit`).
    func run(_ steps: [ScenarioStep]) async {
        var index = 0
        while index < steps.count, !Task.isCancelled {
            switch steps[index] {
            case .loop:
                index = 0
                await Task.yield()
                continue
            case .quit:
                quit()
                return
            case .wait(let seconds):
                await wait(.milliseconds(Int64((max(seconds, 0) * 1000).rounded())))
            case .dump(let label):
                let summary = StatusSummary.of(rig.services, gamma: rig.gamma, triggers: rig.triggers, label: label)
                summaries.append(summary)
                record(summary)
            default:
                perform(steps[index])
            }
            index += 1
        }
    }

    /// One step that changes something.
    func perform(_ step: ScenarioStep) {
        let boost = rig.services.boost
        let signals = rig.signals
        switch step {
        case .on: boost.setOn(true, source: .shortcut)
        case .off: boost.setOn(false, source: .shortcut)
        case .toggle: boost.toggle(source: .shortcut)
        case .standard: boost.returnToStandard(source: .shortcut)
        case .brighter: boost.step(.brighter, source: .shortcut)
        case .lessBright: boost.step(.lessBright, source: .shortcut)
        case .dimAll: boost.toggleDim(source: .shortcut)
        case .level(let level): boost.setLevel(level, for: nil, source: .panel)
        case .dim(let percent): boost.setDimLight(Double(min(max(percent, 2), 99)) / 100, for: nil, source: .panel)
        case let .boost(key, on): setBoostEnabled(on, for: key)
        case .pause(let seconds):
            boost.pause(until: rig.services.time.wallClock.addingTimeInterval(seconds), source: .panel)
        case .resume: boost.resume(source: .panel)
        case .lock(let locked):
            signals.snapshot.isScreenLocked = locked
            signals.emit(locked ? .locked : .unlocked)
        case .systemSleep(let asleep):
            signals.snapshot.isSystemSleeping = asleep
            signals.emit(asleep ? .willSleep : .didWake)
        case .screensSleep(let asleep):
            signals.snapshot.areDisplaysAsleep = asleep
            signals.emit(asleep ? .screensDidSleep : .screensDidWake)
        case .screensaver(let running):
            signals.snapshot.isScreensaverRunning = running
            signals.emit(running ? .screensaverStarted : .screensaverStopped)
        case .session(let active):
            signals.snapshot.isSessionActive = active
            signals.emit(active ? .sessionBecameActive : .sessionResigned)
        case .event(let event): signals.emit(event)
        case .lowPower(let on):
            signals.snapshot.power.isLowPowerMode = on
            signals.emit(.powerChanged)
        case .battery(let percent):
            signals.snapshot.power = PowerState(source: percent == nil ? .adapter : .battery, batteryPercent: percent ?? 100,
                                                isLowPowerMode: signals.snapshot.power.isLowPowerMode)
            signals.emit(.powerChanged)
        case .thermal(let level):
            signals.snapshot.thermal = level
            signals.emit(.thermalChanged(level))
        case let .fullScreen(video, display):
            let keys: Set<DisplayKey> = display.map { [$0] } ?? []
            signals.snapshot.fullScreenDisplays = keys
            signals.snapshot.fullScreenVideoDisplays = video ? keys : []
            signals.emit(.activeSpaceChanged)
        case .focus(let directive): signals.setFocusDirective(directive)
        case .conflict(let severity): setConflict(severity)
        case .wait, .dump, .loop, .quit: break
        }
    }

    private func setBoostEnabled(_ on: Bool, for key: DisplayKey) {
        let settings = rig.services.settings
        var all = settings[DisplaySettings.perDisplay]
        var preferences = all[key] ?? DisplayPreferences()
        preferences.boostEnabled = on
        all[key] = preferences
        settings[DisplaySettings.perDisplay] = all
    }

    /// One synthetic catalogue app of `severity` launches (none: every one quits). Synthetic IDs only (D3).
    private func setConflict(_ severity: ConflictSeverity?) {
        for app in rig.signals.snapshot.conflicts { rig.signals.appTerminated(app, probe: rig.conflicts) }
        guard let severity else { return }
        nextProcessID += 1
        let app = ConflictingApp(entryID: "qa-\(severity.rawValue)", severity: severity,
                                 bundleID: "com.example.qa.\(severity.rawValue)", processID: nextProcessID,
                                 displayName: "QA \(severity.rawValue)")
        rig.signals.appLaunched(app, probe: rig.conflicts)
        log.info("QA: conflict \(severity.rawValue, privacy: .public) running")
    }
}
#endif
