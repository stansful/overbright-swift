// OverbrightBoostTests/Safety/RescueHarness.swift — a launch rescue over the Core fakes, with tables a test chooses.
// ARCHITECTURE.md §7.4, §9.1 (rescue cases with FakeGammaPort).
import CoreGraphics
import Foundation
import OverbrightCore
@testable import OverbrightBoost

/// The fakes behind one `LaunchRescue`: a gamma port whose displays start with the tables a test chooses, a console
/// state, running conflicts, a journal and a settings store holding the boost marker.
@MainActor final class RescueHarness {
    let time = ManualTimeSource()
    let gamma: FakeGammaPort
    let signals = FakeSystemSignals()
    let conflicts = FakeConflictProbe()
    let journal = RingBufferJournal()
    let settings = SettingsStore(defaults: InMemoryDefaults())
    /// The displays the rescue lists (the fixture's, in order).
    let displays: [DisplayRef]

    /// `fixture`'s displays, each at its profile base unless `tables` gives its live table.
    init(fixture: DisplayFixture = .builtinXDRLidOpen, tables: [CGDirectDisplayID: GammaTable] = [:]) {
        gamma = FakeGammaPort(time: time)
        for display in fixture.displays {
            let id = display.facts.ref.id
            gamma.addDisplay(id, base: display.profileBase, table: tables[id] ?? display.profileBase)
        }
        displays = fixture.displays.map(\.facts.ref)
    }

    /// A rescue judging tables with the reference classifier (or the real one), over `port` (default: the fake).
    func rescue(port: (any GammaPort)? = nil, realClassifier: Bool = false) -> LaunchRescue {
        let displays = displays
        if realClassifier {
            return LaunchRescue(gamma: port ?? gamma, conflicts: conflicts, signals: signals, journal: journal,
                                time: time, displays: { displays }, settings: settings)
        }
        return LaunchRescue(gamma: port ?? gamma, conflicts: conflicts, signals: signals, journal: journal, time: time,
                            displays: { displays }, settings: settings,
                            classify: ReferenceTableClassifier.classify(_:expectedBase:),
                            isPlausibleRestore: ReferenceTableClassifier.isPlausibleRestore(_:expectedBase:))
    }

    /// The live table of `id` as the reference classifier judges it against the display's base.
    func tableClass(of id: CGDirectDisplayID) -> TableClass? {
        guard let table = gamma.table(of: id), let base = gamma.base(of: id) else { return nil }
        return ReferenceTableClassifier.classify(table, expectedBase: base)
    }

    /// Our own writes (not the simulated foreign ones), in order.
    var ownWrites: [FakeGammaPort.Write] { gamma.writes.filter { !$0.isForeign } }

    /// Journal codes, in order.
    var codes: [String] { journal.snapshot().map(\.code) }

    /// A running app of `severity` with a synthetic ID (D3: never a real catalogue ID in tests).
    static func app(_ severity: ConflictSeverity, pid: Int32 = 4242) -> ConflictingApp {
        ConflictingApp(entryID: "test.\(severity.rawValue)", severity: severity,
                       bundleID: "com.example.\(severity.rawValue)", processID: pid, displayName: "Example")
    }

    /// A boost marker as the engine leaves it while a display is scaled.
    func setMarker() {
        settings[EngineRecords.boostMarker] = BoostMarker(since: time.wallClock, displays: displays.map(\.key),
                                                          maxFactor: 1.24)
    }
}

/// A gamma port whose global restore does not clear a session-level foreign write: after every restore, `residue` is
/// written again by "another session" (what `residueRemains` reports, §7.4 step 5).
nonisolated final class StickyResidueGamma: GammaPort {
    let port: FakeGammaPort
    let residue: [CGDirectDisplayID: GammaTable]

    init(port: FakeGammaPort, residue: [CGDirectDisplayID: GammaTable]) { self.port = port; self.residue = residue }

    func capacity(of display: CGDirectDisplayID) -> Int { port.capacity(of: display) }
    func read(_ display: CGDirectDisplayID) throws -> GammaTable { try port.read(display) }
    func profileBase(of display: CGDirectDisplayID, count: Int) -> GammaTable {
        port.profileBase(of: display, count: count)
    }
    func write(_ table: GammaTable, to display: CGDirectDisplayID) throws { try port.write(table, to: display) }
    func restoreSystemColorSettings() {
        port.restoreSystemColorSettings()
        for (id, table) in residue { port.foreignWrite(table, to: id) }
    }
    var writeCount: Int { port.writeCount }
}
