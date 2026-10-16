// OverbrightBoostTests/Safety/RestoreVerificationTests.swift — dirty-then-restore and its verification (ARCHITECTURE.md
// §7.4 step 5, D7): the global restore only after a write of ours, every display re-read and judged afterwards, the
// profile base written where the restore left something implausible, and `rescueNow()` (`--restore-gamma`, Reset
// Display Colors) on every display whatever the classification, the marker or other apps say.
import CoreGraphics
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct RestoreVerificationTests {
    private let base = GammaTable.identity(count: 1024)

    // MARK: Order of calls

    @Test func theGlobalRestoreAlwaysFollowsAWriteAndPrecedesTheVerification() async throws {
        let h = RescueHarness(fixture: .russianNames, tables: [2: base.scaled(by: 1.25)])
        let log = CallLogGamma(port: h.gamma)
        #expect(await h.rescue(port: log).runLaunchCheck() == .restored(displays: 1))
        let calls = log.calls
        let restore = try #require(calls.firstIndex(of: .restore))
        let write = try #require(calls.firstIndex(of: .write(2)))
        #expect(write < restore)
        #expect(calls.filter { $0 == .restore }.count == 1)
        // Every display is read again after the restore, not only the one that was scaled.
        let after = calls[restore...]
        #expect(after.contains(.read(1)) && after.contains(.read(2)))
    }

    @Test func aRepairThatCannotBeWrittenIsReportedAsResidue() async {
        let h = RescueHarness(tables: [1: base.scaled(by: 1.3)])
        h.gamma.restoreWritesZeros = true
        let log = CallLogGamma(port: h.gamma, failsWritesAfterRestore: true)
        #expect(await h.rescue(port: log).runLaunchCheck() == .residueRemains(displays: [DisplayFixture.Keys.builtIn]))
        #expect(h.codes.contains("rescue.repairFailed"))
    }

    @Test func aRepairedTableIsJudgedAgainstAFreshProfileBase() async throws {
        let calibrated = try #require(DisplayFixture.calibratedProfile.displays.first?.profileBase)
        let h = RescueHarness(fixture: .calibratedProfile, tables: [1: calibrated.scaled(by: 1.3)])
        h.gamma.restoreWritesZeros = true
        #expect(await h.rescue().runLaunchCheck() == .repairedInvalidRestore(displays: [DisplayFixture.Keys.builtIn]))
        #expect(h.gamma.table(of: 1) == calibrated)                    // the profile's own curve, not identity
    }

    // MARK: rescueNow (--restore-gamma, Reset Display Colors)

    @Test func rescueNowRestoresEvenWhenEverythingLooksNeutral() async {
        let h = RescueHarness()
        #expect(await h.rescue().rescueNow() == .alreadyNeutral)
        #expect(h.ownWrites.count == 1 && h.gamma.restoreCount == 1)   // dirty-then-restore ran
        #expect(h.gamma.table(of: 1) == base)
        #expect(h.codes.contains("rescue.manual"))
    }

    @Test func rescueNowClearsAForeignCurve() async {
        let h = RescueHarness(tables: [1: base.warmed()])
        #expect(await h.rescue().rescueNow() == .restored(displays: 1))
        #expect(h.gamma.table(of: 1) == base)
    }

    @Test func rescueNowIgnoresOtherTableWritersAndNeverWritesAPreference() async {
        let h = RescueHarness(tables: [1: base.scaled(by: 1.3)])
        h.conflicts.running = [RescueHarness.app(.booster)]
        h.setMarker()
        let marker = h.settings[EngineRecords.boostMarker]
        #expect(await h.rescue().rescueNow() == .restored(displays: 1))
        #expect(h.gamma.table(of: 1) == base)
        #expect(h.settings[EngineRecords.boostMarker] == marker)
    }

    @Test func rescueNowDirtiesAScaledDisplayFirst() async throws {
        let h = RescueHarness(fixture: .russianNames, tables: [2: base.scaled(by: 1.3)])
        #expect(await h.rescue().rescueNow() == .restored(displays: 1))
        let write = try #require(h.ownWrites.first)
        #expect(write.display == 2 && write.table == base.scaled(by: 1.3))
    }

    @Test func rescueNowWritesNothingOffTheConsole() async {
        let h = RescueHarness(tables: [1: base.scaled(by: 1.3)])
        h.signals.snapshot.isSessionActive = false
        #expect(await h.rescue().rescueNow() == .skippedNotOnConsole)
        #expect(h.ownWrites.isEmpty && h.gamma.restoreCount == 0)
        #expect(h.gamma.table(of: 1) == base.scaled(by: 1.3))
    }

    @Test func rescueNowReportsResidueAndRepairsLikeTheLaunchCheck() async {
        let h = RescueHarness(tables: [1: base.scaled(by: 1.3)])
        let sticky = StickyResidueGamma(port: h.gamma, residue: [1: base.scaled(by: 1.3)])
        #expect(await h.rescue(port: sticky).rescueNow() == .residueRemains(displays: [DisplayFixture.Keys.builtIn]))
        let zeros = RescueHarness()
        zeros.gamma.restoreWritesZeros = true
        #expect(await zeros.rescue().rescueNow() == .repairedInvalidRestore(displays: [DisplayFixture.Keys.builtIn]))
        #expect(zeros.gamma.table(of: 1) == base)
    }
}

/// A gamma port that logs the order of calls (and can refuse every write after the global restore).
nonisolated final class CallLogGamma: GammaPort, @unchecked Sendable {
    enum Call: Hashable { case read(CGDirectDisplayID), write(CGDirectDisplayID), restore }

    let port: FakeGammaPort
    let failsWritesAfterRestore: Bool
    private let lock = NSLock()
    private var log: [Call] = []          // behind `lock` (the reason for @unchecked Sendable)
    private var restored = false

    init(port: FakeGammaPort, failsWritesAfterRestore: Bool = false) {
        self.port = port; self.failsWritesAfterRestore = failsWritesAfterRestore
    }

    var calls: [Call] { lock.withLock { log } }

    func capacity(of display: CGDirectDisplayID) -> Int { port.capacity(of: display) }
    func read(_ display: CGDirectDisplayID) throws -> GammaTable {
        lock.withLock { log.append(.read(display)) }
        return try port.read(display)
    }
    func profileBase(of display: CGDirectDisplayID, count: Int) -> GammaTable {
        port.profileBase(of: display, count: count)
    }
    func write(_ table: GammaTable, to display: CGDirectDisplayID) throws {
        let refuse = lock.withLock { () -> Bool in
            log.append(.write(display))
            return restored && failsWritesAfterRestore
        }
        if refuse { throw GammaError.coreGraphics(code: 1001) }
        try port.write(table, to: display)
    }
    func restoreSystemColorSettings() {
        lock.withLock { log.append(.restore); restored = true }
        port.restoreSystemColorSettings()
    }
    var writeCount: Int { port.writeCount }
}
