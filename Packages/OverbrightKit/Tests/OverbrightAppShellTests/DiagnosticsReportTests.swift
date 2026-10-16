// OverbrightAppShellTests/DiagnosticsReportTests.swift — `--diagnostics` and Copy Diagnostics are read-only
// (ARCHITECTURE.md §8.4, D24, D26): `diagnosticsNeverWrites` builds the report over ports that fail on any write and
// any window, and checks what smoke reads (`gammaWrites`, `triggerWindows`, `displays`) and the per-display table class.
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct DiagnosticsReportTests {
    private func inputs(fixture: DisplayFixture, gamma: any GammaPort, triggers: any TriggerFactory,
                        settings: SettingsStore, forClipboard: Bool) -> DiagnosticsReport.Inputs {
        DiagnosticsReport.Inputs(
            settings: settings, machine: fixture.machine, journal: RingBufferJournal(), iconVisibility: .visible,
            gamma: gamma, headroom: ScriptedHeadroom(fixture: fixture, time: ManualTimeSource()), triggers: triggers,
            displays: fixture.displays.map(\.facts), signals: FakeSystemSignals(), conflicts: FakeConflictProbe(),
            profileHasVCGT: { _ in false }, simulatedFixture: fixture.rawValue, includesBundleFacts: !forClipboard,
            includesJournal: forClipboard)
    }

    /// The report reads every display's table and profile base, and never writes a table, restores, opens a
    /// trigger or overlay window, or writes a preference.
    @Test func diagnosticsNeverWrites() throws {
        let log = TrapLog()
        let fixture = DisplayFixture.sidecar                              // a built-in with a table, a virtual display
        let fake = FakeGammaPort(fixture: fixture)
        let gamma = TrapGammaPort(forwardingReadsTo: fake)
        let defaults = InMemoryDefaults()
        let settings = SettingsStore(defaults: defaults)
        for forClipboard in [false, true] {
            let report = DiagnosticsReport.build(inputs(fixture: fixture, gamma: gamma,
                                                        triggers: TrapTriggerFactory(log: log), settings: settings,
                                                        forClipboard: forClipboard))
            #expect(report["gammaWrites"] as? Int == 0)
            #expect(report["triggerWindows"] as? Int == 0)
            #expect(DiagnosticsReport.json(report) != nil)
            let displays = try #require(report["displays"] as? [[String: Any]])
            #expect(displays.map { $0["tableClass"] as? String } == ["matchesBase", "noTable"])
            #expect(displays.first?["maxDeviationFromBase"] as? Double == 0)
            #expect((report["journal"] != nil) == forClipboard)
            #expect((report["resourceBundles"] != nil) == !forClipboard)
        }
        #expect(gamma.writes.isEmpty, "diagnostics wrote: \(gamma.writes)")
        #expect(gamma.reads.contains { $0.hasPrefix("read(") })
        #expect(fake.writeCount == 0 && fake.restoreCount == 0)
        #expect(log.calls.allSatisfy { $0 == "triggers.openWindowCount" }, "diagnostics touched triggers: \(log.calls)")
        #expect(defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(SettingsStore.keyPrefix) }.isEmpty)
    }

    /// A scaled table is reported as it is (the class comes from Policy's `TableClassifier`; the deviation from the
    /// profile base is the raw evidence).
    @Test func reportsTheDeviationFromTheProfileBase() throws {
        let fixture = DisplayFixture.builtinXDRLidOpen
        let fake = FakeGammaPort(fixture: fixture)
        let id = try #require(fixture.displays.first?.facts.ref.id)
        let base = try #require(fake.base(of: id))
        fake.foreignWrite(GammaTable(red: base.red.map { $0 * 0.5 }, green: base.green.map { $0 * 0.5 },
                                     blue: base.blue.map { $0 * 0.5 }), to: id)
        let report = DiagnosticsReport.build(inputs(fixture: fixture, gamma: fake, triggers: FakeTriggerFactory(),
                                                    settings: SettingsStore(defaults: InMemoryDefaults()),
                                                    forClipboard: true))
        let display = try #require((report["displays"] as? [[String: Any]])?.first)
        let deviation = try #require(display["maxDeviationFromBase"] as? Double)
        #expect(abs(deviation - 0.5) < 0.001)
        #expect(report["gammaWrites"] as? Int == 0)                       // a foreign write is not ours
    }
}
