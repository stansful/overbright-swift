// OverbrightPanelUI/QA/ScriptedStatuses.swift — named engine statuses for snapshots and `--qa-state`.
// DESIGN.md §5.13; ARCHITECTURE.md §8.5, §10.0 (PanelUI seam). The shell reads `names` and `status(named:)` (fixed);
// `services(named:)` builds a preview hub with the state's settings, directory and Fill Light as well, for the
// snapshot suites and #Previews.
import Foundation
import OverbrightCore

/// The named statuses of DESIGN.md §5.13, each a `BoostStatus` that drives `PreviewBoostControl`.
public enum ScriptedStatuses {
    /// Every name, in gallery order.
    public static var names: [String] { states.map(\.id) }

    /// The status called `name`, or nil for an unknown name.
    public static func status(named name: String) -> BoostStatus? { state(named: name)?.status }

    /// A preview hub showing the state called `name` (its status, displays, settings and Fill Light), or nil for an
    /// unknown name. Every call returns independent fakes and in-memory settings; the wall clock is the state's.
    public static func services(named name: String) -> OverbrightServices? {
        guard let state = state(named: name) else { return nil }
        let settings = SettingsStore(defaults: InMemoryDefaults())
        settings[OnboardingSettings.calibrationTipShown] = true
        state.configure(settings)
        let signals = FakeSystemSignals(snapshot: SystemSnapshot(power: PowerState(source: .battery, batteryPercent: 64,
                                                                                    isLowPowerMode: false)))
        let services = OverbrightServices(
            settings: settings, paths: .temporary(), machine: DisplayFixture.ownerMachine,
            time: ManualTimeSource(start: ScriptedParts.now), journal: RingBufferJournal(),
            announcer: Announcer(post: { _ in }, now: { 0 }), ownEDRSurfaces: OwnEDRSurfaces(),
            displays: FakeDisplayDirectory(displays: state.facts), signals: signals,
            boost: PreviewBoostControl(status: state.status, machine: DisplayFixture.ownerMachine),
            fillLight: PreviewFillLightControl(isOn: state.fillLightOn), shortcuts: PreviewShortcutCenter(),
            updates: PreviewUpdateChecking())
        services.app = PreviewAppControl()
        return services
    }

    /// Whether the state shows the "Why?" row expanded.
    public static func expandsWhy(named name: String) -> Bool { state(named: name)?.expandsWhy ?? false }

    /// The names of the HUD and Keep-this-level states (their snapshots are the shell's HUD windows).
    public static var hudNames: [String] { states.filter(\.isHUDState).map(\.id) }

    // MARK: Private

    /// Every state, built once, each decision at the level its settings give.
    static let states: [ScriptedState] = (ScriptedGallery.panelStates + ScriptedGallery.hudStates)
        .map { $0.withDecisionLevels() }

    static func state(named name: String) -> ScriptedState? { states.first { $0.id == name } }
}
