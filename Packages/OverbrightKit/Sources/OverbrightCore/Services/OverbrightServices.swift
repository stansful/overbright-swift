// OverbrightCore/Services/OverbrightServices.swift — the services hub (replaces Cranny's ModuleRegistry, D23).
// ARCHITECTURE.md §3.9, §3.11. `preview(fixture:)` lives in Fakes/OverbrightServices+Preview.swift.
import Foundation
import Observation

/// Every port, typed as its protocol. Constructing services does no I/O, hardware or network access;
/// `ServiceLifecycle.start()` does. `preview()` (in Fakes/) wires every fake with in-memory settings.
@MainActor @Observable public final class OverbrightServices {
    /// Typed, observable settings.
    public let settings: SettingsStore
    /// Where Overbright writes files.
    public let paths: AppPaths
    /// Model and OS build, read once per launch.
    public let machine: MachineIdentity
    /// Monotonic time, wall clock and sleeping.
    public let time: any TimeSource
    /// The diagnostics ring buffer.
    public let journal: any DiagnosticsJournal
    /// VoiceOver announcements with the app-wide limit.
    public let announcer: Announcer
    /// Displays on which our own EDR content shows.
    public let ownEDRSurfaces: OwnEDRSurfaces
    /// The online displays.
    public let displays: any DisplayDirectory
    /// System state and events.
    public let signals: any SystemSignals
    /// The engine façade.
    public let boost: any BoostControl
    /// The Fill Light façade.
    public let fillLight: any FillLightControl
    /// Global shortcuts.
    public let shortcuts: any ShortcutCenter
    /// The update check.
    public let updates: any UpdateChecking
    /// Set by the shell after construction (it owns the windows that implement it).
    public var app: (any AppControl)?

    /// The hub; the composition root builds the real one, `preview(fixture:)` the fake one.
    public init(settings: SettingsStore, paths: AppPaths, machine: MachineIdentity, time: any TimeSource,
                journal: any DiagnosticsJournal, announcer: Announcer, ownEDRSurfaces: OwnEDRSurfaces,
                displays: any DisplayDirectory, signals: any SystemSignals, boost: any BoostControl,
                fillLight: any FillLightControl, shortcuts: any ShortcutCenter, updates: any UpdateChecking) {
        self.settings = settings; self.paths = paths; self.machine = machine; self.time = time; self.journal = journal
        self.announcer = announcer; self.ownEDRSurfaces = ownEDRSurfaces; self.displays = displays
        self.signals = signals; self.boost = boost; self.fillLight = fillLight; self.shortcuts = shortcuts
        self.updates = updates
    }
}
