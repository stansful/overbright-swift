// OverbrightCore/Fakes/OverbrightServices+Preview.swift — the hub wired with every fake. ARCHITECTURE.md §3.9.
import Foundation

extension OverbrightServices {
    /// Every port as a fake over `fixture`, with in-memory settings (`InMemoryDefaults`: nothing reaches
    /// ~/Library/Preferences), temporary paths (created only on first use), a `ManualTimeSource`, a silent announcer and
    /// `PreviewAppControl`. No I/O, hardware or network access. For `#Preview`, unit tests and `--qa-simulate`.
    /// Every call returns independent settings and fakes.
    public static func preview(fixture: DisplayFixture = .builtinXDRLidOpen) -> OverbrightServices {
        let services = OverbrightServices(
            settings: SettingsStore(defaults: InMemoryDefaults()), paths: .temporary(), machine: fixture.machine,
            time: ManualTimeSource(), journal: RingBufferJournal(), announcer: Announcer(post: { _ in }, now: { 0 }),
            ownEDRSurfaces: OwnEDRSurfaces(), displays: FakeDisplayDirectory(fixture: fixture),
            signals: FakeSystemSignals(), boost: PreviewBoostControl(fixture: fixture),
            fillLight: PreviewFillLightControl(), shortcuts: PreviewShortcutCenter(), updates: PreviewUpdateChecking())
        services.app = PreviewAppControl()
        return services
    }
}
