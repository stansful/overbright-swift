// OverbrightDisplaysTests/Support/GammaPortReadContract.swift — the READ half of the `GammaPort` contract
// (ARCHITECTURE.md §3.6, D26), shared by `GammaPortContractTests` (over `FakeGammaPort`) and the hardware-gated,
// read-only `RealDisplayReadTests` (over the real port). It never writes and never restores.
import CoreGraphics
import OverbrightCore
import Testing

/// Read-only checks every `GammaPort` passes.
enum GammaPortReadContract {
    /// An online display with a transfer table: the read has 2 … capacity entries in three equal channels, reading is
    /// repeatable, the profile base is monotonic at any requested length, and nothing counts as a write.
    static func checkReadable(_ port: any GammaPort, display: CGDirectDisplayID,
                              sourceLocation: SourceLocation = #_sourceLocation) throws {
        let writes = port.writeCount
        let capacity = port.capacity(of: display)
        #expect(capacity > 0, sourceLocation: sourceLocation)
        let table = try port.read(display)
        #expect(table.count >= 2 && table.count <= capacity, sourceLocation: sourceLocation)
        #expect(table.green.count == table.count && table.blue.count == table.count, sourceLocation: sourceLocation)
        #expect(try port.read(display) == table, "reading changes nothing", sourceLocation: sourceLocation)
        for count in [2, table.count, 256, 1024] {
            let base = port.profileBase(of: display, count: count)
            #expect(base.count == count && base.green.count == count && base.blue.count == count,
                    sourceLocation: sourceLocation)
            #expect(isMonotonic(base), "profile base at \(count)", sourceLocation: sourceLocation)
        }
        #expect(port.writeCount == writes, sourceLocation: sourceLocation)
    }

    /// A display ID that is not online: no capacity, a failing read, an identity base.
    static func checkAbsent(_ port: any GammaPort, display: CGDirectDisplayID,
                            sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(port.capacity(of: display) == 0, sourceLocation: sourceLocation)
        #expect(throws: GammaError.displayGone, sourceLocation: sourceLocation) { try port.read(display) }
        #expect(port.profileBase(of: display, count: 64) == .identity(count: 64), sourceLocation: sourceLocation)
    }

    /// Every channel non-decreasing.
    static func isMonotonic(_ table: GammaTable) -> Bool {
        [table.red, table.green, table.blue].allSatisfy { channel in zip(channel, channel.dropFirst()).allSatisfy { $0 <= $1 } }
    }
}
