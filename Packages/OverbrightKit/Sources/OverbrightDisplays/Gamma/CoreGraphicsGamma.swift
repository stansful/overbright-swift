// OverbrightDisplays/Gamma/CoreGraphicsGamma.swift — the real `GammaPort`. ARCHITECTURE.md §2.1 rule 6, §3.6, §4.8,
// §10.4; D7, D24, D26. Thread: nonisolated and `Sendable` (the hang watchdog's queue and the signal queue write ledger
// baselines through it, §8.1 rule 4).
//
// The ONLY file that may call the CoreGraphics table setters and the global ColorSync restore (lint test
// `noSecondDisplayStateWriter`). WP0a SEED: READ-ONLY. `capacity`, `read` and `profileBase` are real, so
// `--diagnostics` can judge every table against its profile base; `write` refuses and the restore does nothing, so
// nothing built before WP2 can change a display. WP2 owns this file and adds the writes, the counter and the restore.
import CoreGraphics
import Foundation
import OverbrightCore

/// Transfer tables through public CoreGraphics; profile bases from the display's ColorSync profile (`vcgt`).
public nonisolated final class CoreGraphicsGamma: GammaPort, Sendable {
    /// The port. Constructing it touches nothing.
    public init() {}

    /// `CGDisplayGammaTableCapacity`; 0 for a display without a table.
    public func capacity(of display: CGDirectDisplayID) -> Int { Int(CGDisplayGammaTableCapacity(display)) }

    /// `CGGetDisplayTransferByTable` (read-only).
    public func read(_ display: CGDirectDisplayID) throws -> GammaTable {
        let capacity = CGDisplayGammaTableCapacity(display)
        guard capacity > 0 else { throw GammaError.noTable }
        var red = [CGGammaValue](repeating: 0, count: Int(capacity))
        var green = red
        var blue = red
        var count: UInt32 = 0
        let error = CGGetDisplayTransferByTable(display, capacity, &red, &green, &blue, &count)
        guard error == .success else { throw GammaError.coreGraphics(code: error.rawValue) }
        let n = Int(min(count, capacity))
        return GammaTable(red: Array(red.prefix(n)), green: Array(green.prefix(n)), blue: Array(blue.prefix(n)))
    }

    /// The profile's `vcgt` resampled to `count`, identity when the profile has none. Never reads the live table.
    public func profileBase(of display: CGDirectDisplayID, count: Int) -> GammaTable {
        guard let vcgt = vcgt(of: display) else { return .identity(count: count) }
        return vcgt.table(count: count)
    }

    /// Whether the display's ColorSync profile carries a `vcgt` tag (diagnostics).
    public func profileHasVCGT(of display: CGDirectDisplayID) -> Bool { vcgt(of: display) != nil }

    /// WP0a seed: refuses every write (WP2 adds the CoreGraphics setter here, and only here).
    public func write(_ table: GammaTable, to display: CGDirectDisplayID) throws {
        _ = (table, display)
        throw GammaError.writeRefused
    }

    /// WP0a seed: does nothing (WP2 adds the global restore here, and only here).
    public func restoreSystemColorSettings() {}

    /// Successful writes since launch: always 0 in the read-only seed.
    public var writeCount: Int { 0 }

    private func vcgt(of display: CGDirectDisplayID) -> ProfileVCGT? {
        guard let data = CGDisplayCopyColorSpace(display).copyICCData() as Data? else { return nil }
        return ProfileVCGT.parse(iccData: data)
    }
}
