// OverbrightSignalsTests/Fakes/SignalsHarness.swift — a `SignalsMonitor` over fakes with manual time. ARCHITECTURE.md
// §9.1 (no real sleeping; `ManualTimeSource` moves only when a test advances it).
import Foundation
import OverbrightCore
@testable import OverbrightSignals

@MainActor final class SignalsHarness {
    let time = ManualTimeSource()
    let defaults = InMemoryDefaults()
    let settings: SettingsStore
    let journal = RingBufferJournal()
    let directory: FakeDisplayDirectory
    let platform = FakeSignalsPlatform()
    let apps = FakeRunningApps()
    let probe: RunningAppsConflictProbe
    let monitor: SignalsMonitor
    var calendar: Calendar

    init(fixture: DisplayFixture = .builtinXDRLidOpen, timeZone: TimeZone = TimeZone(identifier: "UTC") ?? .current) {
        settings = SettingsStore(defaults: defaults)
        directory = FakeDisplayDirectory(fixture: fixture)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
        probe = RunningAppsConflictProbe(catalog: TestCatalog.all, ownBundleID: "app.overbright.Overbright",
                                         source: apps, match: TestCatalog.match)
        monitor = SignalsMonitor(settings: settings, time: time, journal: journal, displays: directory,
                                 platform: platform, conflicts: probe, calendar: calendar)
    }

    func start() async { await monitor.start() }

    /// Lets main-actor work queued by observation callbacks run.
    func settle() async {
        for _ in 0..<25 { await Task.yield() }
    }

    /// Lets pending tasks start their sleeps, advances manual time (sleepers due on the way wake in order) and settles.
    func advance(_ duration: Duration) async {
        await settle()
        await time.advance(by: duration)
        await settle()
    }
}
