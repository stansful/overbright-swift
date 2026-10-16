// OverbrightAppShell/App/ShellPorts.swift — the ports one wiring of the composition root provides: the simulated ones
// of `--qa-simulate` or the real ones. ARCHITECTURE.md §3.9, §3.11, §10.0 (shared shell file), §10.15.
import CoreGraphics
import OverbrightCore
import OverbrightHotKeys
import OverbrightIntents

/// The ports one wiring provides, the services among them that start and stop, and the event relays that keep them
/// connected (`makeShell` adds the engine and the control's publish point).
struct ShellPorts {
    /// Tables and profile bases.
    var gamma: any GammaPort
    /// EDR values.
    var headroom: any HeadroomPort
    /// The online displays.
    var displays: any DisplayDirectory
    /// Trigger and overlay windows.
    var triggers: any TriggerFactory
    /// The system snapshot and events (Displays' events are relayed into it).
    var signals: any SystemSignals
    /// What the launch check reads (the real wiring reads the console itself until Signals has started, §7.4).
    var launchCheckSignals: any SystemSignals
    /// Conflicting apps.
    var conflicts: any ConflictProbe
    /// Fill Light.
    var fillLight: any FillLightControl
    /// Global shortcuts.
    var shortcuts: any ShortcutCenter
    /// The hot-key center behind `shortcuts`, whose presses the composition root routes to the engine (nil: none).
    var hotKeys: HotKeyCenter?
    /// The update check.
    var updates: any UpdateChecking
    /// The login item (`SMAppService.mainApp`; in memory under `--qa-simulate`).
    var loginItems: any LoginItemService
    /// Where the control's state goes (silent under `--qa-simulate`).
    var controlOutlet: any ControlStateOutlet
    /// A read-only snapshot of the online displays for `--diagnostics` and the launch check (no service started).
    var readDisplays: () -> [DisplayFacts]
    /// Whether a display's profile has a `vcgt` tag (nil: unknown).
    var profileHasVCGT: (CGDirectDisplayID) -> Bool?
    /// The built-in panel's backlight now, in milli-nits (diagnostics, H-N1); nil without one.
    var backlightMilliNits: () -> Double?
    /// The services among these ports that start and stop (`makeShell` adds Intents and Boost).
    var services: ServiceStack
    /// Event relays kept for the life of the launch (Displays → Signals).
    var relays: [ObservationToken]
    /// The `--qa-simulate` fixture, nil for real ports.
    var fixture: DisplayFixture?
}
