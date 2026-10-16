// OverbrightCore/Platform/LaunchArguments.swift — the one parser for command-line arguments: the Release switches
// (`--off`, `--restore-gamma`, `--diagnostics <file|->`, `--monitor [seconds]`) and the Debug QA hooks of
// ARCHITECTURE.md §8.5. Ported from Cranny's LaunchArguments.swift (the owner's MIT code); pure: tests pass their own
// arguments. The parser only names the Debug-only switches (`debugOnlySwitches`); what a build does with them is the
// shell's decision (a Release build refuses to start, `CompositionRoot.refusedSwitches`), and so is the D27
// single-instance exemption, which follows the ports actually wired (`CompositionRoot.skipsSingleInstanceCheck`).
// `--qa-simulate` is a switch with an optional value: its presence (`qaSimulates`) selects the fakes, its value only
// the fixture, so a missing or mistyped name never reaches the real ports.
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

    // MARK: Debug QA switches (§8.5)

    /// The prefixes of the Debug-only switches: `--qa-…` and the Settings window's `-OverbrightQA…` defaults.
    public static let debugOnlyPrefixes = ["--qa-", "-OverbrightQA"]

    /// The Debug-only switches present, in order (`["--qa-simulate", "--qa-defaults-suite"]`); empty for a launch with
    /// Release switches only.
    public var debugOnlySwitches: [String] {
        values.filter { value in Self.debugOnlyPrefixes.contains { value.hasPrefix($0) } }
    }

    /// `--qa-defaults-suite <name>`: keep the run's settings in that suite (only `QAHooks+Defaults.swift` creates it).
    public var qaDefaultsSuite: String? { value(after: "--qa-defaults-suite") }

    /// `--qa-simulate [fixture]`: fakes instead of every display port and EDR surface, with or without a fixture name.
    /// The switch alone decides the wiring (`CompositionRoot.simulatedFixture(for:)`), never the name.
    public var qaSimulates: Bool { contains("--qa-simulate") }

    /// The fixture name after `--qa-simulate` (a `DisplayFixture` raw value); nil when the switch is absent, last or
    /// followed by another switch (`--qa-simulate --off`). A nil name with `qaSimulates` true still means fakes.
    public var qaSimulateFixture: String? {
        guard let name = value(after: "--qa-simulate"), !name.hasPrefix("-") else { return nil }
        return name
    }

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

    /// `--qa-script "<steps>"`: a scenario over the simulated ports (the shell's `ScenarioScript`, ARCHITECTURE.md §8.5).
    public var qaScript: String? { value(after: "--qa-script") }

    /// `--qa-status <file>`: where the scenario's `dump` lines go (JSON lines).
    public var qaStatusFile: String? { value(after: "--qa-status") }

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
