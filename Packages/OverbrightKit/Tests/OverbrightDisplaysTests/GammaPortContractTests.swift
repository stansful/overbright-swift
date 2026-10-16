// OverbrightDisplaysTests/GammaPortContractTests.swift — the `GammaPort` contract (ARCHITECTURE.md §3.6, §7.4, §9.1
// "write and restore cases only against FakeGammaPort", D7, D26): reads, profile bases that never come from the live
// table, both read-back models, writes counted only on success, failures that write nothing, the global restore that
// does nothing until this process wrote a table, and counting from several threads. The real port's read half is in
// the hardware-gated `RealDisplayReadTests`; its write machinery (`GammaWriteGate`) in `GammaWriteGateTests`.
import CoreGraphics
import Dispatch
import OverbrightCore
import Testing
@testable import OverbrightDisplays

@Suite struct GammaPortContractTests {
    nonisolated private func scaled(_ table: GammaTable, by factor: Float) -> GammaTable {
        GammaTable(red: table.red.map { $0 * factor }, green: table.green.map { $0 * factor },
                   blue: table.blue.map { $0 * factor })
    }

    @Test(arguments: DisplayFixture.allCases)
    func readContractHoldsForEveryFixture(_ fixture: DisplayFixture) throws {
        let port = FakeGammaPort(fixture: fixture)
        for display in fixture.displays {
            let id = display.facts.ref.id
            if display.profileBase == nil {
                #expect(port.capacity(of: id) == 0)
                #expect(throws: GammaError.noTable) { try port.read(id) }
            } else {
                try GammaPortReadContract.checkReadable(port, display: id)
            }
        }
        GammaPortReadContract.checkAbsent(port, display: 0x0BAD_F00D)
        #expect(port.writeCount == 0)
    }

    @Test func aWriteReadsBackAndLeavesTheProfileBaseAlone() throws {
        let port = FakeGammaPort(fixture: .calibratedProfile)
        let base = port.profileBase(of: 1, count: 1024)
        let boosted = scaled(try port.read(1), by: 1.237)
        try port.write(boosted, to: 1)
        #expect(port.writeCount == 1)
        #expect(try port.read(1) == boosted)
        #expect(port.profileBase(of: 1, count: 1024) == base)            // derived without the live table (D26)
    }

    @Test func readBackMayClampAboveOne() throws {
        let port = FakeGammaPort(fixture: .builtinXDRLidOpen)
        port.clampsReadBack = true
        let boosted = scaled(try port.read(1), by: 1.5)
        try port.write(boosted, to: 1)
        let read = try port.read(1)
        #expect(read.maximum == 1)                                        // the model the classifier must survive
        #expect(port.table(of: 1) == boosted)                             // WindowServer still holds the boost
        #expect(port.profileBase(of: 1, count: 1024) == .identity(count: 1024))
    }

    @Test func failedWritesWriteNothingAndAreNotCounted() throws {
        let port = FakeGammaPort(fixture: .hardwareMirror)
        let before = try port.read(6)
        port.removeDisplay(6)
        #expect(throws: GammaError.displayGone) { try port.write(before, to: 6) }
        #expect(throws: GammaError.noTable) { try FakeGammaPort(fixture: .sidecar).write(before, to: 5) }
        port.failNextWrite(with: .coreGraphics(code: 1001))
        let table = try port.read(1)
        #expect(throws: GammaError.coreGraphics(code: 1001)) { try port.write(scaled(table, by: 0.5), to: 1) }
        #expect(try port.read(1) == table)
        #expect(port.writeCount == 0)
    }

    @Test func theGlobalRestoreDoesNothingUntilThisProcessWroteATable() throws {
        let port = FakeGammaPort(fixture: .builtinXDRLidOpen)
        let foreign = scaled(try port.read(1), by: 1.3)
        port.foreignWrite(foreign, to: 1)
        port.restoreSystemColorSettings()
        #expect(try port.read(1) == foreign)                              // hence dirty-then-restore (D7)
        try port.write(foreign, to: 1)                                    // dirty: our connection wrote a table
        port.restoreSystemColorSettings()
        #expect(try port.read(1) == .identity(count: 1024))
        #expect(port.restoreCount == 2)
    }

    @Test func aFailedRestoreCanLeaveZeros() throws {
        let port = FakeGammaPort(fixture: .builtinXDRLidOpen)
        port.restoreWritesZeros = true
        try port.write(try port.read(1), to: 1)
        port.restoreSystemColorSettings()
        #expect(try port.read(1).maximum == 0)                            // LaunchRescue's verification must catch it
    }

    @Test func writesFromSeveralThreadsAreAllCounted() throws {
        let port = FakeGammaPort(fixture: .sidecar)
        let table = try port.read(1)
        let tables = (0..<4).map { scaled(table, by: 1 + Float($0) / 100) }
        DispatchQueue.concurrentPerform(iterations: 64) { index in
            try? port.write(tables[index % 4], to: 1)
        }
        #expect(port.writeCount == 64)
        #expect(port.writes.count == 64)
    }
}
