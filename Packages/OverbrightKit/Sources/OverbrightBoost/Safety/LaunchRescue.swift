// OverbrightBoost/Safety/LaunchRescue.swift — the launch check and the dirty-then-restore rescue. ARCHITECTURE.md
// §7.4, D7, D26, D27. Seeded by WP0a with the fixed signatures (§10.0); owned by WP5, which writes the body (console
// check, classification against profile bases, the known-table-writer rule, dirty-then-restore with verification and
// explicit profile-base repair). The WP0a body reads nothing and writes nothing.
import OverbrightCore

/// Decides at launch (and for `--restore-gamma` and Advanced ▸ Reset Display Colors) whether a display carries a
/// leftover table, and clears it. With `TableWriter`, the only caller of `GammaPort.write` and
/// `restoreSystemColorSettings()` (lint test `onlyTableWriterAndRescueWrite`).
public final class LaunchRescue {
    private let gamma: any GammaPort
    private let conflicts: any ConflictProbe
    private let signals: any SystemSignals
    private let journal: any DiagnosticsJournal
    private let time: any TimeSource
    private let onlineDisplays: @MainActor () -> [DisplayRef]
    private let settings: SettingsStore?

    /// A rescue over the real or fake ports that reads the online displays from CoreGraphics (read-only) and keeps no
    /// boost marker. Prefer `init(gamma:conflicts:signals:journal:time:displays:settings:)`.
    public convenience init(gamma: any GammaPort, conflicts: any ConflictProbe, signals: any SystemSignals,
                            journal: any DiagnosticsJournal) {
        self.init(gamma: gamma, conflicts: conflicts, signals: signals, journal: journal, time: SystemTimeSource(),
                  displays: OnlineDisplays.coreGraphics, settings: nil)
    }

    /// A rescue over the real or fake ports. `displays` lists the online displays (the composition root passes its
    /// read-only snapshot; the services have not started when the launch check runs); `settings` holds the boost
    /// marker (`EngineRecords.boostMarker`), which the launch check reads and clears; `time` stamps the journal.
    public init(gamma: any GammaPort, conflicts: any ConflictProbe, signals: any SystemSignals,
                journal: any DiagnosticsJournal, time: any TimeSource,
                displays: @escaping @MainActor () -> [DisplayRef], settings: SettingsStore?) {
        self.gamma = gamma; self.conflicts = conflicts; self.signals = signals; self.journal = journal
        self.time = time; self.onlineDisplays = displays; self.settings = settings
    }

    /// The launch check (§7.4), before any other display work. WP0a seed: reports neutral without reading.
    public func runLaunchCheck() async -> RescueOutcome { .alreadyNeutral }

    /// Dirty-then-restore with verification on every display, whatever the boost marker says (`--restore-gamma`,
    /// Reset Display Colors). WP0a seed: does nothing and reports neutral.
    public func rescueNow() async -> RescueOutcome { .alreadyNeutral }
}
