// OverbrightBoostTests/Safety/LaunchRescueRealClassifierTests.swift — the launch-rescue decision table again, through
// the public initializer and Policy's own `TableClassifier` (ARCHITECTURE.md §7.4, D26). Enabled once WP1's body
// replaces the WP0a stub (which calls every table `matchesBase`); until then `LaunchRescueTests` covers the table with
// the reference classifier.
import CoreGraphics
import OverbrightCore
import Testing
@testable import OverbrightBoost

@MainActor @Suite(.enabled(if: PolicyClassifierProbe.isReal, "needs WP1's TableClassifier"))
struct LaunchRescueRealClassifierTests {
    private let base = GammaTable.identity(count: 1024)

    @Test func neutralAndMarker() async {
        let h = RescueHarness()
        h.setMarker()
        #expect(await h.rescue(realClassifier: true).runLaunchCheck() == .alreadyNeutral)
        #expect(h.codes.contains("launch.recoveredByWindowServer") && h.ownWrites.isEmpty)
    }

    @Test(arguments: [false, true])
    func residueAloneIsCleared(clampsReadBack: Bool) async {
        let h = RescueHarness(tables: [1: base.scaled(by: 1.3)])
        h.gamma.clampsReadBack = clampsReadBack
        #expect(await h.rescue(realClassifier: true).runLaunchCheck() == .restored(displays: 1))
        #expect(h.gamma.table(of: 1) == base)
    }

    @Test func residueWhileATableWriterRuns() async {
        let h = RescueHarness(tables: [1: base.scaled(by: 1.3)])
        let app = RescueHarness.app(.gammaWriter)
        h.conflicts.running = [app]
        #expect(await h.rescue(realClassifier: true).runLaunchCheck() == .skippedBecauseTableWriterRuns(app))
        #expect(h.ownWrites.isEmpty)
    }

    @Test func zerosAfterTheRestoreAreRepaired() async {
        let h = RescueHarness(tables: [1: base.scaled(by: 1.3)])
        h.gamma.restoreWritesZeros = true
        #expect(await h.rescue(realClassifier: true).runLaunchCheck()
                == .repairedInvalidRestore(displays: [DisplayFixture.Keys.builtIn]))
        #expect(h.gamma.table(of: 1) == base)
    }

    @Test func residueThatStays() async {
        let h = RescueHarness(tables: [1: base.scaled(by: 1.3)])
        let sticky = StickyResidueGamma(port: h.gamma, residue: [1: base.scaled(by: 1.3)])
        #expect(await h.rescue(port: sticky, realClassifier: true).runLaunchCheck()
                == .residueRemains(displays: [DisplayFixture.Keys.builtIn]))
    }

    @Test func notOnConsole() async {
        let h = RescueHarness(tables: [1: base.scaled(by: 1.3)])
        h.signals.snapshot.isSessionActive = false
        #expect(await h.rescue(realClassifier: true).runLaunchCheck() == .skippedNotOnConsole)
        #expect(h.ownWrites.isEmpty)
    }
}
