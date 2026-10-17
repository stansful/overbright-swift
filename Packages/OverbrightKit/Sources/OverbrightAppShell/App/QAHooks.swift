// OverbrightAppShell/App/QAHooks.swift — DEBUG-only visual QA launch arguments. ARCHITECTURE.md §8.5; Cranny's
// QAHooks (the owner's MIT code). Shared shell file. The whole file is compiled out of Release.
//
//   --qa-simulate [fixture]          fakes for every display port (CompositionRoot; with no or an unknown name,
//                                    builtin-xdr-lid-open); mandatory for agents
//   --qa-defaults-suite <name>       settings in that suite (QAHooks+Defaults.swift)
//   --qa-state <name>                a named state of PanelUI's `ScriptedStatuses`: `PreviewBoostControl` shows its
//                                    status, its settings go into the run's suite (in memory without one), Fill Light
//                                    and the "Why?" row show as the state says (`scriptedState`)
//   --qa-panel                       open the panel (it then stays open on clicks elsewhere until the run ends)
//   --qa-menu                        write the status menu's rows to qa-trace.txt (next to --qa-snapshot), open it
//   --qa-hud <level>                 under --qa-simulate, set every display to that level as a shortcut would, so
//                                    the HUD shows it (bright-room, max, -0.5, …); otherwise, and for anything else,
//                                    only the HUD's generic level change (the real displays are never set)
//   --qa-settings <pane[#row]>, --qa-welcome <step>, --qa-calibration <display>, --qa-help <anchor>
//   --qa-script "<steps>"            run a scenario over the simulated ports once the services started
//                                    (`ScenarioScript`; e.g. "on; wait 6; dump boosted; low-power on; dump paused")
//   --qa-status <file>               where the scenario's `dump` lines go (JSON lines; else the log)
//   --qa-snapshot <dir> [--qa-snapshot-at <s>]   render every visible window in-process into <dir>
//                                    (QAHooks+Snapshot.swift; by default 3 s after the launch work, 2 s with
//                                    --qa-hud and 1 s for a HUD state, while the HUD shows)
//   --qa-exit-after <s>              quit after that many seconds
//   --qa-update-check                run the update check at once
//   --qa-hang-main <delay>,<duration>  block the main thread (hang-watchdog test H-X1; the owner's session only)
//   -OverbrightQAAppearance light|dark   pins the app's appearance, so every surface follows it
//
// Everything that shows a surface (the panel, the menu, the HUD, Settings, Welcome, the calibration window, Help) and
// the snapshot is timed from the end of the launch work (`BoostStatus.isReady`, at most `readinessWait`): before it,
// the calibration window had no engine to ask for a session and Help no registered shortcut. `--qa-exit-after` and
// `--qa-hang-main` count from the launch. QA hooks never synthesize input and never ask for permissions. A scenario and
// a `--qa-hud` level change run only over the simulated ports.
#if DEBUG
import AppKit
import Foundation
import OverbrightCore
import OverbrightPanelUI
import os

private let log = Log.logger(.app)

/// The Debug QA hooks.
enum QAHooks {
    /// What the hooks act on.
    struct Targets {
        let shell: Shell
        let appControl: ShellAppControl
        let welcome: WelcomeWindowController
        let statusItem: StatusItemController
        let hud: HUDController
    }

    /// What `--qa-state <name>` shows besides the engine's status.
    struct ScriptedState {
        /// The engine's status (`PreviewBoostControl`).
        let status: BoostStatus
        /// Fill Light is on (`PreviewFillLightControl`).
        let fillLightOn: Bool
        /// The panel opens with the "Why?" row expanded.
        let expandsWhy: Bool
    }

    /// The longest wait for the launch work before the surfaces show anyway (logged).
    static let readinessWait: Duration = .seconds(10)

    /// The status `--qa-state <name>` asks for, nil without the switch or for an unknown name.
    static func scriptedStatus(_ arguments: LaunchArguments) -> BoostStatus? {
        guard let name = arguments.qaState else { return nil }
        guard let status = ScriptedStatuses.status(named: name) else {
            log.error("QA: unknown --qa-state \(name, privacy: .public); known: \(ScriptedStatuses.names.joined(separator: ", "), privacy: .public)")
            return nil
        }
        return status
    }

    /// `--qa-state <name>`: the state, with its settings written into `settings` when they are a QA suite's
    /// (`qaSuite`; `QAHooks.defaults` gives a run with `--qa-state` in-memory settings when it names no suite), so the
    /// thumbs, the switches, the link glyphs, the HUD bars and the calibration marks agree with the status's readouts.
    /// Nil without the switch or for an unknown name.
    static func scriptedState(_ arguments: LaunchArguments, settings: SettingsStore, qaSuite: String?) -> ScriptedState? {
        guard let name = arguments.qaState, let status = scriptedStatus(arguments) else { return nil }
        if qaSuite != nil {
            ScriptedStatuses.apply(named: name, to: settings)
            log.info("QA: --qa-state \(name, privacy: .public) with its settings")
        } else {
            log.error("QA: --qa-state \(name, privacy: .public) without a QA suite: its settings are not written")
        }
        return ScriptedState(status: status, fillLightOn: ScriptedStatuses.fillLightOn(named: name),
                             expandsWhy: ScriptedStatuses.expandsWhy(named: name))
    }

    /// `--qa-panel`: the panel stays open on clicks elsewhere (a mouse-down anywhere in the session closed it before
    /// the capture in about one run in eight).
    static func keepsPanelOpen(_ arguments: LaunchArguments) -> Bool { arguments.qaOpensPanel }

    /// When the snapshot is taken after the launch work: `--qa-snapshot-at`, else while a level HUD shows (it goes
    /// 1.5 s after it appeared): 2 s with `--qa-hud` (it shows 1 s in), 1 s for a HUD state (it shows at once); 3 s
    /// otherwise.
    static func snapshotDelay(_ arguments: LaunchArguments) -> Double {
        if let at = arguments.qaSnapshotAt { return at }
        if arguments.qaHUDLevel != nil { return 2 }
        if let state = arguments.qaState, ScriptedStatuses.hudNames.contains(state) { return 1 }
        return 3
    }

    /// Applies every hook of `arguments`; returns the task that shows the surfaces once the launch work is done and
    /// runs the scenario, if any (the app cancels it at quit).
    static func apply(_ arguments: LaunchArguments, to targets: Targets) -> Task<Void, Never>? {
        if let exit = arguments.qaExitAfter, exit > 0 {
            after(seconds(exit)) {
                log.info("QA: exiting after \(exit, privacy: .public) s")
                NSApp.terminate(nil)
            }
        }
        if let hang = arguments.qaHangMain {
            after(hang.delay) {
                log.info("QA: blocking the main thread for \(hang.duration.timeInterval, privacy: .public) s")
                Thread.sleep(forTimeInterval: hang.duration.timeInterval)
            }
        }
        let boost = targets.shell.services.boost
        return Task {
            await waitUntilReady(boost)
            guard !Task.isCancelled else { return }
            showSurfaces(arguments, targets: targets)
            guard let script = arguments.qaScript else { return }
            let scenario = runScenario(script, statusFile: arguments.qaStatusFile, shell: targets.shell,
                                       appControl: targets.appControl)
            await withTaskCancellationHandler { await scenario?.value } onCancel: { scenario?.cancel() }
        }
    }

    /// The surfaces and the snapshot, timed from now (the end of the launch work).
    private static func showSurfaces(_ arguments: LaunchArguments, targets: Targets) {
        let control = targets.appControl
        let snapshotDirectory = arguments.qaSnapshotDirectory.map { URL(fileURLWithPath: $0, isDirectory: true) }
        if arguments.qaOpensPanel { after(.milliseconds(500)) { control.showPanel() } }
        if arguments.qaOpensMenu {
            after(.seconds(1)) { targets.statusItem.runMenuQA(traceDirectory: snapshotDirectory) }
        }
        if let level = arguments.qaHUDLevel { after(.seconds(1)) { showHUD(level, targets: targets) } }
        if let pane = arguments.qaSettingsPane { control.openSettings(pane) }
        if let step = arguments.qaWelcomeStep { targets.welcome.show(step: step) }
        if let display = arguments.qaCalibrationDisplay { control.showCalibration(for: DisplayKey(rawValue: display)) }
        if let anchor = arguments.qaHelpAnchor { control.showHelp(anchor: anchor) }
        if arguments.qaRunsUpdateCheck { targets.shell.services.updates.checkNow() }
        if let snapshotDirectory {
            after(seconds(snapshotDelay(arguments))) { capture(into: snapshotDirectory) }
        }
    }

    /// Returns once the engine is ready (the launch work is done), or after `readinessWait`.
    static func waitUntilReady(_ boost: any BoostControl, polling interval: Duration = .milliseconds(100)) async {
        let deadline = ContinuousClock.now + readinessWait
        while !boost.status.isReady, !Task.isCancelled {
            guard ContinuousClock.now < deadline else {
                log.error("QA: the engine was not ready after \(readinessWait.timeInterval, privacy: .public) s; showing the surfaces anyway")
                return
            }
            try? await Task.sleep(for: interval)
        }
    }

    /// `--qa-hud <level>`: under `--qa-simulate`, a level the scenario script can name ("bright-room", "max", "-0.5")
    /// is set on every display as a shortcut would, so the HUD shows that level for real; on the real ports (a Debug
    /// hardware session) and for anything else, the HUD shows its generic level change and no display is set.
    static func showHUD(_ level: String, targets: Targets) {
        if let position = hudLevel(level, ports: targets.shell.ports) {
            targets.shell.services.boost.setLevel(position, for: nil, source: .shortcut)
        } else {
            targets.hud.showForQA(level)
        }
    }

    /// The level `--qa-hud <level>` sets: nil unless the ports are the simulated ones and the script can name it.
    static func hudLevel(_ level: String, ports: ShellPorts) -> LevelPosition? {
        guard ports.fixture != nil else { return nil }
        guard case .level(let position)? = try? ScenarioScript.parse("level \(level)").first else { return nil }
        return position
    }

    /// Parses `script` and runs it over the simulated ports once the engine is ready; nil (logged) when it cannot run.
    /// `panel open|close` acts on `appControl`'s panel.
    static func runScenario(_ script: String, statusFile: String?, shell: Shell,
                            appControl: ShellAppControl) -> Task<Void, Never>? {
        guard let rig = ScenarioRunner.Rig(shell: shell) else {
            log.error("QA: --qa-script needs --qa-simulate; nothing runs")
            return nil
        }
        let steps: [ScenarioStep]
        do { steps = try ScenarioScript.parse(script) } catch {
            log.error("QA: \(String(describing: error), privacy: .public)")
            return nil
        }
        let output = statusFile.map { URL(fileURLWithPath: $0) }
        if let output { try? Data().write(to: output) }                      // a fresh file per run
        let runner = ScenarioRunner(rig: rig, wait: { duration in try? await Task.sleep(for: duration) },
                                    record: { summary in append(summary.jsonLine, to: output) },
                                    quit: { NSApp.terminate(nil) },
                                    panel: { open in open ? appControl.showPanel() : appControl.closePanel() })
        let boost = shell.services.boost
        return Task {
            while !boost.status.isReady, !Task.isCancelled { try? await Task.sleep(for: .milliseconds(100)) }
            log.info("QA: scenario of \(steps.count, privacy: .public) steps starts")
            await runner.run(steps)
        }
    }

    private static func append(_ line: String, to url: URL?) {
        guard let url else {
            log.info("QA: \(line, privacy: .public)")
            return
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data((line + "\n").utf8))
    }

    private static func after(_ delay: Duration, _ action: @escaping @MainActor () -> Void) {
        Task {
            try? await Task.sleep(for: delay)
            action()
        }
    }

    /// `value` seconds, at most a day (an infinite value too); a negative value or not a number is none. Never traps.
    static func seconds(_ value: Double) -> Duration {
        guard !value.isNaN, value > 0 else { return .zero }
        return .milliseconds(Int64((min(value, 86_400) * 1000).rounded()))
    }
}
#endif
