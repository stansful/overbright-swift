// OverbrightAppShell/App/QAHooks.swift — DEBUG-only visual QA launch arguments. ARCHITECTURE.md §8.5; Cranny's
// QAHooks (the owner's MIT code). Shared shell file. The whole file is compiled out of Release.
//
//   --qa-simulate [fixture]          fakes for every display port (CompositionRoot; with no or an unknown name,
//                                    builtin-xdr-lid-open); mandatory for agents
//   --qa-defaults-suite <name>       settings in that suite (QAHooks+Defaults.swift)
//   --qa-state <name>                drive `PreviewBoostControl` with PanelUI's `ScriptedStatuses` (CompositionRoot)
//   --qa-panel                       open the panel
//   --qa-menu                        write the status menu's rows to qa-trace.txt (next to --qa-snapshot), open it
//   --qa-hud <level>                 under --qa-simulate, set every display to that level as a shortcut would, so
//                                    the HUD shows it (bright-room, max, -0.5, …); otherwise, and for anything else,
//                                    only the HUD's generic level change (the real displays are never set)
//   --qa-settings <pane[#row]>, --qa-welcome <step>, --qa-calibration <display>, --qa-help <anchor>
//   --qa-script "<steps>"            run a scenario over the simulated ports once the services started
//                                    (`ScenarioScript`; e.g. "on; wait 6; dump boosted; low-power on; dump paused")
//   --qa-status <file>               where the scenario's `dump` lines go (JSON lines; else the log)
//   --qa-snapshot <dir> [--qa-snapshot-at <s>]   render every visible window in-process into <dir> (default 3 s)
//   --qa-exit-after <s>              quit after that many seconds
//   --qa-update-check                run the update check at once
//   --qa-hang-main <delay>,<duration>  block the main thread (hang-watchdog test H-X1; the owner's session only)
//
// QA hooks never synthesize input and never ask for permissions. A scenario and a `--qa-hud` level change run only over
// the simulated ports.
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

    /// The status `--qa-state <name>` asks for, nil without the switch or for an unknown name.
    static func scriptedStatus(_ arguments: LaunchArguments) -> BoostStatus? {
        guard let name = arguments.qaState else { return nil }
        guard let status = ScriptedStatuses.status(named: name) else {
            log.error("QA: unknown --qa-state \(name, privacy: .public); known: \(ScriptedStatuses.names.joined(separator: ", "), privacy: .public)")
            return nil
        }
        return status
    }

    /// Applies every hook of `arguments`; returns the running scenario, if any (the app cancels it at quit).
    static func apply(_ arguments: LaunchArguments, to targets: Targets) -> Task<Void, Never>? {
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
            after(seconds(arguments.qaSnapshotAt ?? 3)) { capture(into: snapshotDirectory) }
        }
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
        guard let script = arguments.qaScript else { return nil }
        return runScenario(script, statusFile: arguments.qaStatusFile, shell: targets.shell, appControl: control)
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

    /// Draws each visible window's content into `<directory>/window-<number>.png` (in-process `cacheDisplay`: works
    /// without Screen Recording access and while displays sleep; menus cannot be rendered).
    static func capture(into directory: URL) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            log.error("QA: snapshot folder: \(error.localizedDescription, privacy: .public)")
            return
        }
        for window in NSApp.windows where window.isVisible {
            guard let view = window.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                continue
            }
            view.cacheDisplay(in: view.bounds, to: rep)
            guard let data = rep.representation(using: .png, properties: [:]) else { continue }
            let kind = window is OverbrightPanel ? "panel" : "window"
            let url = directory.appending(path: "\(kind)-\(window.windowNumber).png")
            do {
                try data.write(to: url)
                log.info("QA: snapshot \(url.lastPathComponent, privacy: .public)")
            } catch {
                log.error("QA: snapshot failed: \(error.localizedDescription, privacy: .public)")
            }
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

    private static func seconds(_ value: Double) -> Duration { .milliseconds(Int64((max(value, 0) * 1000).rounded())) }
}
#endif
