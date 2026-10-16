// OverbrightCore/Ports/GammaPort.swift — the only path to the display transfer tables (implemented by OverbrightDisplays).
// ARCHITECTURE.md §3.6, §4.5, D7, D24, D26.
// Contract rule (§10.0): a requirement added after WP0a lands only together with a default implementation in a
// protocol extension in this file.
import CoreGraphics

/// The ONLY path to `CGGet/SetDisplayTransferByTable` and `CGDisplayRestoreColorSyncSettings`.
/// Nonisolated and Sendable: the hang watchdog and the signal queue write ledger baselines off the main actor (D7).
public protocol GammaPort: Sendable {
    /// `CGDisplayGammaTableCapacity`; 0 = no table.
    func capacity(of display: CGDirectDisplayID) -> Int
    /// The live table as read back.
    func read(_ display: CGDirectDisplayID) throws -> GammaTable
    /// The table macOS restores for this display, derived WITHOUT the live table: the ColorSync profile's `vcgt`
    /// (public ColorSync / `CGDisplayCopyColorSpace` ICC data), resampled to `count`; identity when absent (D26).
    func profileBase(of display: CGDirectDisplayID, count: Int) -> GammaTable
    /// Writes as-is. Only Boost's `TableWriter` (normal, calibration and ledger-baseline paths) and `LaunchRescue`
    /// call it (§4.5 invariant 3).
    func write(_ table: GammaTable, to display: CGDirectDisplayID) throws
    /// Global ColorSync restore. Rescue paths only (D7, §7.4); a no-op unless this process wrote a table first.
    func restoreSystemColorSettings()
    /// Number of successful writes since launch (diagnostics `gammaWrites`; smoke asserts 0).
    var writeCount: Int { get }
}
