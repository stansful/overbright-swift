// OverbrightDisplays/Gamma/CoreGraphicsGamma.swift — the real `GammaPort`. ARCHITECTURE.md §2.1 rule 6, §3.6, §4.8,
// §7.4, §10.4; D7, D24, D26. Thread: nonisolated and `Sendable`: the hang watchdog's queue and the signal queue write
// ledger baselines through it (§8.1 rule 4). CoreGraphics' transfer calls are messages to WindowServer; every write and
// the restore go through one `GammaWriteGate`, so they never overlap and `writeCount` counts accepted writes only.
//
// The ONLY file that may call the CoreGraphics table setters and the global ColorSync restore (lint test
// `noSecondDisplayStateWriter`). Only Boost's `TableWriter` and `LaunchRescue` call `write` and the restore (lint test
// `onlyTableWriterAndRescueWrite`); tests never construct this port outside hardware-gated, read-only suites (D24).
import ColorSync
import CoreGraphics
import Foundation
import OverbrightCore
import os

nonisolated private let log = Log.logger(.gamma)

/// Transfer tables through public CoreGraphics; profile bases from the display's ColorSync profile (`vcgt`).
public nonisolated final class CoreGraphicsGamma: GammaPort, Sendable {
    private let gate = GammaWriteGate()

    /// The port. Constructing it touches nothing.
    public init() {}

    /// `CGDisplayGammaTableCapacity`; 0 for a display without a table.
    public func capacity(of display: CGDirectDisplayID) -> Int { Int(CGDisplayGammaTableCapacity(display)) }

    /// `CGGetDisplayTransferByTable` (read-only). Throws `displayGone` for an ID that is no longer online and
    /// `noTable` for a display without a table.
    public func read(_ display: CGDirectDisplayID) throws -> GammaTable {
        guard isOnline(display) else { throw GammaError.displayGone }
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

    /// The profile's `vcgt` (sampled table or formula) resampled to `count`, identity when the profile has none.
    /// Never reads the live table (D26).
    public func profileBase(of display: CGDirectDisplayID, count: Int) -> GammaTable {
        ProfileBase.table(iccData: iccData(of: display), count: count)
    }

    /// Whether the display's ColorSync profile carries a `vcgt` tag (diagnostics).
    public func profileHasVCGT(of display: CGDirectDisplayID) -> Bool {
        iccData(of: display).flatMap(ProfileVCGT.parse(iccData:)) != nil
    }

    /// `CGSetDisplayTransferByTable` with `table` as given (TableWriter has applied the interlock). Throws
    /// `displayGone`, `noTable`, `coreGraphics(illegalArgument)` for a malformed table, or CoreGraphics' error.
    public func write(_ table: GammaTable, to display: CGDirectDisplayID) throws {
        do {
            try gate.perform(table, online: isOnline(display), capacity: capacity(of: display)) { table in
                CGSetDisplayTransferByTable(display, UInt32(table.count), table.red, table.green, table.blue)
            }
        } catch {
            log.error("gamma: write to display \(display, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    /// `CGDisplayRestoreColorSyncSettings`: every display back to its ColorSync profile. Rescue paths only (D7); a no-op
    /// unless this process wrote a table first, hence LaunchRescue's dirty-then-restore.
    public func restoreSystemColorSettings() {
        gate.performRestore { CGDisplayRestoreColorSyncSettings() }
        log.info("gamma: global ColorSync restore")
    }

    /// Successful writes since launch (diagnostics `gammaWrites`; smoke asserts 0).
    public var writeCount: Int { gate.successfulWrites }

    // MARK: Private

    /// The ID is in the online list (`CGDisplayIsOnline` answers true for IDs CoreGraphics never knew).
    private func isOnline(_ display: CGDirectDisplayID) -> Bool {
        CoreGraphicsDisplayReader.onlineIDs().contains(display)
    }

    private func iccData(of display: CGDirectDisplayID) -> Data? {
        CGDisplayCopyColorSpace(display).copyICCData() as Data?
    }
}
