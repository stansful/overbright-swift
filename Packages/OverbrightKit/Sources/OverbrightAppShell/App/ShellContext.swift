// OverbrightAppShell/App/ShellContext.swift — what every wiring of the composition root shares: the settings, the
// paths, the Mac, the clock, the journal, the own-EDR registry and the announcer. ARCHITECTURE.md §3.9, §3.11, §10.15.
// Built once per launch (AppDelegate) before the ports, because the real Signals, Fill Light, shortcuts and update
// check need them; constructing it does no I/O.
import OverbrightCore

/// The values every service and port of one launch shares.
struct ShellContext {
    /// Typed, observable settings (the launch's defaults: the standard domain or a QA suite).
    let settings: SettingsStore
    /// Where Overbright writes files (temporary folders under `--qa-simulate`).
    let paths: AppPaths
    /// The Mac and OS build (the fixture's under `--qa-simulate`).
    let machine: MachineIdentity
    /// Monotonic time, wall clock and sleeping.
    let time: any TimeSource
    /// The diagnostics ring buffer every service records into.
    let journal: any DiagnosticsJournal
    /// Displays on which our own EDR content shows (Fill Light, the Welcome card, the calibration window).
    let ownEDRSurfaces: OwnEDRSurfaces
    /// VoiceOver announcements with the app-wide limit.
    let announcer: Announcer
    /// The `--qa-defaults-suite` of a Debug QA run (`ShellDefaults.qaSuite`), nil for the standard domain: such a run
    /// writes nothing to the app's own preferences domain, the control's channel included.
    let qaSuite: String?

    /// A context with a fresh journal, own-EDR registry and announcer.
    init(settings: SettingsStore, paths: AppPaths, machine: MachineIdentity, time: any TimeSource,
         journal: any DiagnosticsJournal = RingBufferJournal(), ownEDRSurfaces: OwnEDRSurfaces = OwnEDRSurfaces(),
         announcer: Announcer = Announcer(), qaSuite: String? = nil) {
        self.settings = settings; self.paths = paths; self.machine = machine; self.time = time
        self.journal = journal; self.ownEDRSurfaces = ownEDRSurfaces; self.announcer = announcer
        self.qaSuite = qaSuite
    }
}
