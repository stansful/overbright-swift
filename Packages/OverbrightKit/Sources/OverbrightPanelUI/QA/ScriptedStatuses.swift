// OverbrightPanelUI/QA/ScriptedStatuses.swift — named engine statuses for snapshots and `--qa-state`.
// DESIGN.md §5.13; ARCHITECTURE.md §8.5, §10.0 (PanelUI seam). The shell reads `names` and `status(named:)` (fixed),
// and for `--qa-state` also what is not part of the status: `apply(named:to:)` writes the state's settings (levels, cap
// modes, linked levels, the per-display switch, calibration records, whether the panel shows external displays) into
// the run's QA suite, `fillLightOn(named:)` and `expandsWhy(named:)` say how Fill Light and the "Why?" row show;
// without them a scripted status contradicts itself in the app (a readout at one level with the thumb at another). `services(named:)` builds a preview hub with
// the state's settings, directory and Fill Light, for the snapshot suites and #Previews.
import Foundation
import OverbrightCore

/// The named statuses of DESIGN.md §5.13, each a `BoostStatus` that drives `PreviewBoostControl`.
public enum ScriptedStatuses {
    /// Every name, in gallery order.
    public static var names: [String] { states.map(\.id) }

    /// The status called `name`, or nil for an unknown name.
    public static func status(named name: String) -> BoostStatus? { state(named: name)?.status }

    /// Writes the settings the state called `name` needs into `settings`, after setting back to their defaults the
    /// ones any state writes (so a QA suite kept between runs shows this state alone), marking the calibration tip as
    /// shown (only `calibration-tip` shows it) and showing external displays in the panel (all but the
    /// `externals-hidden` states). False, and nothing written, for an unknown name.
    @discardableResult
    public static func apply(named name: String, to settings: SettingsStore) -> Bool {
        guard let state = state(named: name) else { return false }
        settings.reset(DisplaySettings.perDisplay)
        settings.reset(DisplaySettings.linkLevels)
        settings.reset(DisplaySettings.linkedLevel)
        settings.reset(DisplaySettings.boostOnlyNearFullBrightness)
        settings.reset(AutomationSettings.autoOffMinutes)
        settings[OnboardingSettings.calibrationTipShown] = true
        settings[DisplaySettings.showsExternalDisplaysInPanel] = state.showsExternalDisplays
        state.configure(settings)
        return true
    }

    /// Whether the state called `name` shows Fill Light on (false for an unknown name).
    public static func fillLightOn(named name: String) -> Bool { state(named: name)?.fillLightOn ?? false }

    /// A preview hub showing the state called `name` (its status, displays, settings and Fill Light), or nil for an
    /// unknown name. Every call returns independent fakes and in-memory settings; the wall clock is the state's.
    public static func services(named name: String) -> OverbrightServices? {
        guard let state = state(named: name) else { return nil }
        let settings = SettingsStore(defaults: InMemoryDefaults())
        apply(named: name, to: settings)
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
