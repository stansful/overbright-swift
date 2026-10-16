// OverbrightAppShell/App/ShellPorts.swift — the ports one wiring of the composition root provides: the simulated ones
// of `--qa-simulate` or the real ones. ARCHITECTURE.md §3.9, §3.11, §10.0 (shared shell file, contract owner), §10.15.
import CoreGraphics
import OverbrightCore

/// The ports one wiring provides.
struct ShellPorts {
    /// Tables and profile bases.
    var gamma: any GammaPort
    /// EDR values.
    var headroom: any HeadroomPort
    /// The online displays.
    var displays: any DisplayDirectory
    /// Trigger and overlay windows.
    var triggers: any TriggerFactory
    /// The system snapshot and events.
    var signals: any SystemSignals
    /// Conflicting apps.
    var conflicts: any ConflictProbe
    /// Fill Light.
    var fillLight: any FillLightControl
    /// Global shortcuts.
    var shortcuts: any ShortcutCenter
    /// The update check.
    var updates: any UpdateChecking
    /// A read-only snapshot of the online displays for `--diagnostics` (no service started).
    var readDisplays: () -> [DisplayFacts]
    /// Whether a display's profile has a `vcgt` tag (nil: unknown).
    var profileHasVCGT: (CGDirectDisplayID) -> Bool?
    /// Services with a lifecycle of their own, in start order (Boost is appended last by `makeShell`).
    var lifecycle: [any ServiceLifecycle]
    /// The ports that are placeholders in this wiring (`--diagnostics` shows them as null).
    var placeholders: Set<Placeholder>
    /// The `--qa-simulate` fixture, nil for real ports.
    var fixture: DisplayFixture?

    /// A port without a real implementation yet.
    enum Placeholder: Hashable { case signals, conflicts }
}
