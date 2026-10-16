// OverbrightCore/Platform/LaunchArguments.swift — the one parser for command-line arguments: the Release switches
// (`--off`, `--restore-gamma`, `--diagnostics <file|->`, `--monitor [seconds]`) and the Debug QA hooks of
// ARCHITECTURE.md §8.5. Ported from Cranny's LaunchArguments.swift (the owner's MIT code); pure: tests pass their own
// arguments. Whether a Release build honours a QA switch is the shell's decision (`QAHooks`), not the parser's.
import Foundation

/// Command-line arguments as `--name value` pairs and bare flags.
public nonisolated struct LaunchArguments: Sendable, Equatable {
    /// All arguments, the executable path first (as `ProcessInfo.arguments`).
    public let values: [String]

    /// The arguments to parse.
    public init(_ values: [String]) { self.values = values }

    /// This process's arguments.
    public static var current: LaunchArguments { LaunchArguments(ProcessInfo.processInfo.arguments) }

    /// Whether the bare flag `name` is present (`--off`).
    public func contains(_ name: String) -> Bool { values.contains(name) }

    /// The argument after the first `name` (`value(after: "--qa-simulate")` → "builtin-xdr-lid-open"), or nil when
    /// `name` is absent or last.
    public func value(after name: String) -> String? {
        guard let index = values.firstIndex(of: name), index + 1 < values.count else { return nil }
        return values[index + 1]
    }

    /// `value(after:)` as an integer, nil when absent or not a number.
    public func int(after name: String) -> Int? { value(after: name).flatMap { Int($0) } }

    /// `value(after:)` as a number, nil when absent or not a number.
    public func double(after name: String) -> Double? { value(after: name).flatMap { Double($0) } }

    // MARK: Release switches (every build)

    /// `--off`: start with the master off whatever the launch behaviour.
    public var startsOff: Bool { contains("--off") }

    /// `--restore-gamma`: dirty-then-restore with verification on every display, print the result, quit (§7.4).
    public var restoresGamma: Bool { contains("--restore-gamma") }

    /// `--diagnostics <file|->`: where the read-only report goes ("-" = standard output, also when no path follows);
    /// nil without the switch.
    public var diagnosticsPath: String? {
        guard contains("--diagnostics") else { return nil }
        guard let path = value(after: "--diagnostics"), !path.hasPrefix("--") else { return "-" }
        return path
    }

    /// `--monitor [seconds]`: the read-only monitor runs (until Ctrl-C, or for `monitorDuration`).
    public var runsMonitor: Bool { contains("--monitor") }

    /// The optional duration after `--monitor`; nil = until Ctrl-C (or no monitor).
    public var monitorDuration: Duration? {
        guard runsMonitor, let seconds = double(after: "--monitor"), seconds.isFinite, seconds > 0 else { return nil }
        return .milliseconds(Int64((seconds * 1000).rounded()))
    }

    /// A command-line mode (`--diagnostics`, `--monitor`, `--restore-gamma`): it starts no service and opens no UI.
    public var isCommandLineMode: Bool { diagnosticsPath != nil || runsMonitor || restoresGamma }

    /// Exempt from the single-instance check (D27): a command-line mode or a `--qa-simulate` run.
    public var skipsSingleInstanceCheck: Bool { isCommandLineMode || qaSimulateFixture != nil }

    // MARK: Debug QA switches (§8.5)

    /// `--qa-defaults-suite <name>`: keep the run's settings in that suite (only `QAHooks+Defaults.swift` creates it).
    public var qaDefaultsSuite: String? { value(after: "--qa-defaults-suite") }

    /// `--qa-simulate <fixture>`: fakes instead of every display port and EDR surface (`DisplayFixture` raw value).
    public var qaSimulateFixture: String? { value(after: "--qa-simulate") }

    /// `--qa-panel`: open the panel.
    public var qaOpensPanel: Bool { contains("--qa-panel") }

    /// `--qa-menu`: open the status menu (its rows are dumped to `qa-trace.txt`).
    public var qaOpensMenu: Bool { contains("--qa-menu") }

    /// `--qa-hud <level>`: show the HUD with this level.
    public var qaHUDLevel: String? { value(after: "--qa-hud") }

    /// `--qa-settings <pane[#row]>`: open Settings at a place.
    public var qaSettingsPane: String? { value(after: "--qa-settings") }

    /// `--qa-welcome <step>`: open Welcome at a step.
    public var qaWelcomeStep: String? { value(after: "--qa-welcome") }

    /// `--qa-calibration <display>`: open the calibration window for a display.
    public var qaCalibrationDisplay: String? { value(after: "--qa-calibration") }

    /// `--qa-help <anchor>`: open Help at an anchor.
    public var qaHelpAnchor: String? { value(after: "--qa-help") }

    /// `--qa-state <scripted status>`: drive `PreviewBoostControl` with a named status (PanelUI's `ScriptedStatuses`).
    public var qaState: String? { value(after: "--qa-state") }

    /// `--qa-snapshot <dir>`: in-process window snapshots are written there.
    public var qaSnapshotDirectory: String? { value(after: "--qa-snapshot") }

    /// `--qa-snapshot-at <s>`: when the snapshots are taken.
    public var qaSnapshotAt: Double? { double(after: "--qa-snapshot-at") }

    /// `--qa-exit-after <s>`: quit after this many seconds.
    public var qaExitAfter: Double? { double(after: "--qa-exit-after") }

    /// `--qa-update-check`: run the update check at once.
    public var qaRunsUpdateCheck: Bool { contains("--qa-update-check") }

    /// `--qa-hang-main <delay>,<duration>` (seconds): block the main thread for `duration` after `delay` (hang-watchdog
    /// test H-X1, the owner's session only); nil when absent or malformed.
    public var qaHangMain: (delay: Duration, duration: Duration)? {
        guard let parts = value(after: "--qa-hang-main")?.split(separator: ","), parts.count == 2,
              let delay = Double(parts[0]), let duration = Double(parts[1]),
              delay.isFinite, duration.isFinite, delay >= 0, duration > 0 else { return nil }
        return (.milliseconds(Int64((delay * 1000).rounded())), .milliseconds(Int64((duration * 1000).rounded())))
    }
}
