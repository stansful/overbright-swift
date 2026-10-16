// OverbrightDisplays/Gamma/GammaWriteGate.swift — validation, serialization and counting of transfer-table writes.
// ARCHITECTURE.md §3.6 (`GammaPort.write`, `writeCount`), §7.4, §8.1 rule 4, §10.4; D7, D24. Thread: any.
//
// `CoreGraphicsGamma` sends every write and the global restore through one gate, so the CoreGraphics setter is called
// by one thread at a time (main, the hang watchdog's queue, the signal queue), in the order the callers acquired the
// lock, and `writeCount` counts exactly the writes CoreGraphics accepted. The gate itself knows nothing of
// CoreGraphics' setters: the caller passes the call in, so the gate is tested without a display.
import CoreGraphics
import Foundation
import OverbrightCore

/// Serializes and counts table writes. `@unchecked Sendable`: `writes` is only touched under `lock`, an `NSLock`
/// because it is held across a WindowServer call (§8.1 rules 4 and 7).
nonisolated final class GammaWriteGate: @unchecked Sendable {
    private let lock = NSLock()
    private var writes = 0

    /// A gate with no writes yet.
    init() {}

    /// Writes accepted by CoreGraphics so far.
    var successfulWrites: Int { lock.withLock { writes } }

    /// Validates `table` for a display that is `online` with `capacity` entries, then runs `apply` under the lock and
    /// counts it when it returns `.success`. Throws `displayGone`, `noTable`, `coreGraphics(illegalArgument)` for a
    /// malformed table (fewer than 2 entries, more than the capacity, channels of different lengths, a non-finite or
    /// negative entry), or `coreGraphics(code)` for CoreGraphics' own refusal.
    func perform(_ table: GammaTable, online: Bool, capacity: Int, apply: (GammaTable) -> CGError) throws {
        guard online else { throw GammaError.displayGone }
        guard capacity > 0 else { throw GammaError.noTable }
        guard Self.isWritable(table, capacity: capacity) else {
            throw GammaError.coreGraphics(code: CGError.illegalArgument.rawValue)
        }
        try lock.withLock {
            let result = apply(table)
            guard result == .success else { throw GammaError.coreGraphics(code: result.rawValue) }
            writes += 1
        }
    }

    /// Runs `apply` (the global ColorSync restore) under the same lock, so it never interleaves with a write.
    func performRestore(_ apply: () -> Void) {
        lock.withLock(apply)
    }

    /// A table CoreGraphics can take: 2 … `capacity` entries, three channels of one length, every entry finite and
    /// ≥ 0 (entries above 1 are the boost and are allowed).
    static func isWritable(_ table: GammaTable, capacity: Int) -> Bool {
        let count = table.count
        guard count >= 2, count <= capacity, table.green.count == count, table.blue.count == count else { return false }
        return [table.red, table.green, table.blue].allSatisfy { channel in
            channel.allSatisfy { $0.isFinite && $0 >= 0 }
        }
    }
}
