// OverbrightBoostTests/Safety/LaunchRescueTests.swift — the launch check's decision table (ARCHITECTURE.md §7.4, §10.7
// acceptance): not on console; neutral; marker + neutral; residue + table writer; residue alone → cleared; restore
// leaves zeros → profile base written; residue that stays → reported. Every case runs on FakeGammaPort with the
// reference D26 classifier; `LaunchRescueRealClassifierTests` repeats them once WP1's classifier lands.
import CoreGraphics
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct LaunchRescueTests {
    private let builtIn: CGDirectDisplayID = 1
    private let base = GammaTable.identity(count: 1024)

    // MARK: Not on the console (D27)

    @Test func offTheConsoleNothingIsReadOrWrittenUntilTheSessionReturns() async throws {
        let h = RescueHarness(tables: [1: base.scaled(by: 1.3)])
        h.signals.snapshot.isSessionActive = false
        let rescue = h.rescue()
        #expect(await rescue.runLaunchCheck() == .skippedNotOnConsole)
        #expect(h.ownWrites.isEmpty && h.gamma.restoreCount == 0)
        #expect(h.gamma.table(of: builtIn) == base.scaled(by: 1.3))
        #expect(h.codes.contains("launch.notOnConsole"))
        #expect(rescue.deferredCheck == nil)

        var deferred: RescueOutcome?
        rescue.onDeferredOutcome = { deferred = $0 }
        h.signals.emit(.sessionBecameActive)                 // the event alone counts as "on the console"
        let outcome = try #require(await rescue.deferredCheck?.value)
        #expect(outcome == .restored(displays: 1))
        #expect(deferred == outcome && rescue.lastOutcome == outcome)
        #expect(h.gamma.table(of: builtIn) == base)
        h.signals.emit(.sessionBecameActive)                 // ran once: the wait ended
        #expect(h.gamma.restoreCount == 1)
    }

    @Test func otherEventsDoNotRunTheDeferredCheck() async {
        let h = RescueHarness(tables: [1: base.scaled(by: 1.3)])
        h.signals.snapshot.isSessionActive = false
        let rescue = h.rescue()
        #expect(await rescue.runLaunchCheck() == .skippedNotOnConsole)
        h.signals.emit([.unlocked, .didWake, .screensDidWake, .displaysReconfigured])
        #expect(rescue.deferredCheck == nil && h.ownWrites.isEmpty)
    }

    // MARK: Neutral

    @Test func neutralTablesAreLeftAlone() async {
        let h = RescueHarness(fixture: .sidecar)               // the built-in plus a display without a table
        #expect(await h.rescue().runLaunchCheck() == .alreadyNeutral)
        #expect(h.ownWrites.isEmpty && h.gamma.restoreCount == 0)
        #expect(!h.codes.contains("launch.recoveredByWindowServer"))
    }

    @Test func aMarkerWithNeutralTablesMeansWindowServerRestored() async {
        let h = RescueHarness()
        h.setMarker()
        #expect(await h.rescue().runLaunchCheck() == .alreadyNeutral)
        #expect(h.codes.contains("launch.recoveredByWindowServer"))
        #expect(h.settings[EngineRecords.boostMarker] == nil)
        #expect(h.ownWrites.isEmpty && h.gamma.restoreCount == 0)
    }

    @Test func aForeignCurveAloneIsNotRescued() async {
        let h = RescueHarness(tables: [1: base.warmed()])
        #expect(h.tableClass(of: builtIn) == .foreign)
        #expect(await h.rescue().runLaunchCheck() == .alreadyNeutral)
        #expect(h.gamma.table(of: builtIn) == base.warmed())
        #expect(h.ownWrites.isEmpty && h.gamma.restoreCount == 0)
        #expect(h.codes.contains("launch.foreignTable"))
    }

    // MARK: Residue and other table writers (§7.2)

    @Test(arguments: [ConflictSeverity.booster, .gammaWriter, .conditional])
    func residueWhileAKnownTableWriterRunsIsTheirs(_ severity: ConflictSeverity) async {
        let h = RescueHarness(tables: [1: base.scaled(by: 1.3)])
        let app = RescueHarness.app(severity)
        h.conflicts.running = [RescueHarness.app(.benign, pid: 7), app]
        h.setMarker()
        #expect(await h.rescue().runLaunchCheck() == .skippedBecauseTableWriterRuns(app))
        #expect(h.gamma.table(of: builtIn) == base.scaled(by: 1.3))
        #expect(h.ownWrites.isEmpty && h.gamma.restoreCount == 0)
        #expect(h.codes.contains("launch.skippedTableWriter"))
    }

    @Test func theBoosterIsNamedBeforeOtherWriters() async {
        let h = RescueHarness(tables: [1: base.scaled(by: 1.3)])
        h.conflicts.running = [RescueHarness.app(.conditional, pid: 1), RescueHarness.app(.gammaWriter, pid: 2),
                               RescueHarness.app(.booster, pid: 3)]
        #expect(await h.rescue().runLaunchCheck() == .skippedBecauseTableWriterRuns(RescueHarness.app(.booster, pid: 3)))
    }

    @Test func aBenignAppDoesNotStopTheRescue() async {
        let h = RescueHarness(tables: [1: base.scaled(by: 1.3)])
        h.conflicts.running = [RescueHarness.app(.benign)]
        #expect(await h.rescue().runLaunchCheck() == .restored(displays: 1))
        #expect(h.gamma.table(of: builtIn) == base)
    }

    @Test(arguments: [Float(1.3), 1.05, 0.5, 0.95])
    func residueAloneIsClearedByDirtyThenRestore(_ factor: Float) async throws {
        let residue = base.scaled(by: factor)
        let h = RescueHarness(tables: [1: residue])
        h.setMarker()
        #expect(await h.rescue().runLaunchCheck() == .restored(displays: 1))
        #expect(h.gamma.table(of: builtIn) == base)
        // Exactly one write, the read-back table unchanged, before the one global restore.
        let write = try #require(h.ownWrites.first)
        #expect(h.ownWrites.count == 1 && write.display == builtIn && write.table == residue)
        #expect(h.gamma.restoreCount == 1)
        #expect(h.codes.contains("launch.rescued"))
        #expect(h.settings[EngineRecords.boostMarker] == nil)
    }

    @Test func clampedReadBackIsRescuedTheSameWay() async throws {
        let h = RescueHarness(tables: [1: base.scaled(by: 1.3)])
        h.gamma.clampsReadBack = true
        #expect(await h.rescue().runLaunchCheck() == .restored(displays: 1))
        #expect(h.gamma.table(of: builtIn) == base)
        // The dirty write is what was read back: clamped at 1.0, never above it.
        let write = try #require(h.ownWrites.first)
        #expect(write.table.maximum <= 1)
    }

    @Test func anInvalidTableAtLaunchIsRescued() async {
        let h = RescueHarness(tables: [1: .zeros(count: 1024)])
        #expect(h.tableClass(of: builtIn) == .invalid)
        #expect(await h.rescue().runLaunchCheck() == .restored(displays: 1))
        #expect(h.gamma.table(of: builtIn) == base)
    }

    @Test func aCalibratedBaseIsWhatTheRescueRestores() async throws {
        let calibrated = try #require(DisplayFixture.calibratedProfile.displays.first?.profileBase)
        let h = RescueHarness(fixture: .calibratedProfile, tables: [1: calibrated.scaled(by: 1.2)])
        #expect(await h.rescue().runLaunchCheck() == .restored(displays: 1))
        #expect(h.gamma.table(of: builtIn) == calibrated)
    }

    @Test func onlyOneDisplayIsDirtiedForSeveralResidues() async {
        let h = RescueHarness(fixture: .russianNames, tables: [1: base.scaled(by: 1.3), 2: base.scaled(by: 1.2)])
        #expect(await h.rescue().runLaunchCheck() == .restored(displays: 2))
        #expect(h.ownWrites.count == 1 && h.gamma.restoreCount == 1)
        #expect(h.gamma.table(of: 1) == base && h.gamma.table(of: 2) == base)
    }

    @Test func aFailedDirtyWriteTriesTheNextAffectedDisplay() async {
        let h = RescueHarness(fixture: .russianNames, tables: [1: base.scaled(by: 1.3), 2: base.scaled(by: 1.2)])
        h.gamma.failNextWrite(with: .coreGraphics(code: 1001))
        #expect(await h.rescue().runLaunchCheck() == .restored(displays: 2))
        #expect(h.ownWrites.map(\.display) == [2])
        #expect(h.codes.contains("rescue.dirtyWriteFailed"))
    }

    // MARK: After the restore

    @Test func aRestoreThatLeavesZerosGetsTheProfileBaseWritten() async {
        let h = RescueHarness(fixture: .russianNames, tables: [1: base.scaled(by: 1.3)])
        h.gamma.restoreWritesZeros = true
        let builtInKey = DisplayFixture.Keys.builtIn, msi = DisplayFixture.Keys.mpg322ux
        #expect(await h.rescue().runLaunchCheck() == .repairedInvalidRestore(displays: [builtInKey, msi]))
        #expect(h.gamma.table(of: 1) == base && h.gamma.table(of: 2) == base)
        #expect(Array(h.ownWrites.dropFirst()).map(\.table) == [base, base])     // after the dirty write
        #expect(h.codes.filter { $0 == "launch.repairedInvalidRestore" }.count == 2)
    }

    @Test func residueThatSurvivesTheRestoreIsReported() async {
        let h = RescueHarness(tables: [1: base.scaled(by: 1.3)])
        let sticky = StickyResidueGamma(port: h.gamma, residue: [1: base.scaled(by: 1.3)])
        #expect(await h.rescue(port: sticky).runLaunchCheck() == .residueRemains(displays: [DisplayFixture.Keys.builtIn]))
        #expect(h.codes.contains("launch.residueRemains"))
        #expect(h.gamma.restoreCount == 1)
    }

    @Test func aDisplayWithoutATableIsNeverRead() async {
        let h = RescueHarness(fixture: .sidecar, tables: [1: base.scaled(by: 1.3)])
        #expect(await h.rescue().runLaunchCheck() == .restored(displays: 1))
        #expect(h.ownWrites.allSatisfy { $0.display == 1 })
        #expect(!h.codes.contains("rescue.readFailed"))
    }

    @Test func aDisplayThatVanishedIsSkipped() async {
        let h = RescueHarness(fixture: .russianNames, tables: [1: base.scaled(by: 1.3)])
        h.gamma.removeDisplay(2)
        #expect(await h.rescue().runLaunchCheck() == .restored(displays: 1))
    }
}
