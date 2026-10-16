// OverbrightAppShell/App/QAHooks.swift — DEBUG-only visual QA launch arguments. ARCHITECTURE.md §8.5; Cranny's
// QAHooks (the owner's MIT code). Shared shell file (contract owner). The whole file is compiled out of Release.
//
//   --qa-simulate [fixture]          fakes for every display port (CompositionRoot; with no or an unknown name,
//                                    builtin-xdr-lid-open); mandatory for agents
//   --qa-defaults-suite <name>       settings in that suite (QAHooks+Defaults.swift)
//   --qa-state <name>                drive `PreviewBoostControl` with PanelUI's `ScriptedStatuses` (CompositionRoot)
//   --qa-panel                       open the panel
//   --qa-menu, --qa-hud <level>      the status menu and the HUD (WP10; logged until then)
//   --qa-settings <pane[#row]>, --qa-welcome <step>, --qa-calibration <display>, --qa-help <anchor>
//   --qa-snapshot <dir> [--qa-snapshot-at <s>]   render every visible window in-process into <dir> (default 3 s)
//   --qa-exit-after <s>              quit after that many seconds
//   --qa-update-check                run the update check at once
//   --qa-hang-main <delay>,<duration>  block the main thread (hang-watchdog test H-X1; the owner's session only)
//
// QA hooks never synthesize input and never ask for permissions.
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
        let services: OverbrightServices
        let appControl: ShellAppControl
        let welcome: WelcomeWindowController
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

    /// Applies every hook of `arguments`.
    static func apply(_ arguments: LaunchArguments, to targets: Targets) {
        let control = targets.appControl
        if arguments.qaOpensPanel { after(.milliseconds(500)) { control.showPanel() } }
        if arguments.qaOpensMenu { log.info("QA: --qa-menu lands with WP10") }
        if let level = arguments.qaHUDLevel { log.info("QA: --qa-hud \(level, privacy: .public) lands with WP10") }
        if let pane = arguments.qaSettingsPane { control.openSettings(pane) }
        if let step = arguments.qaWelcomeStep { targets.welcome.show(step: step) }
        if let display = arguments.qaCalibrationDisplay { control.showCalibration(for: DisplayKey(rawValue: display)) }
        if let anchor = arguments.qaHelpAnchor { control.showHelp(anchor: anchor) }
        if arguments.qaRunsUpdateCheck { targets.services.updates.checkNow() }
        if let path = arguments.qaSnapshotDirectory {
            let directory = URL(fileURLWithPath: path, isDirectory: true)
            after(seconds(arguments.qaSnapshotAt ?? 3)) { capture(into: directory) }
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

    private static func after(_ delay: Duration, _ action: @escaping @MainActor () -> Void) {
        Task {
            try? await Task.sleep(for: delay)
            action()
        }
    }

    private static func seconds(_ value: Double) -> Duration { .milliseconds(Int64((max(value, 0) * 1000).rounded())) }
}
#endif
