// OverbrightDisplays/Gamma/ProfileBase.swift — the expected base of a display from its ColorSync profile's ICC data
// (D26). ARCHITECTURE.md §3.6 (`GammaPort.profileBase`), §4.8, §10.4. Pure: never reads the live table.
import Foundation
import OverbrightCore

/// The table macOS restores for a display: its profile's `vcgt` (sampled table or formula) resampled to the table
/// length, identity when the profile has no `vcgt`, the tag is malformed, or there is no profile.
nonisolated enum ProfileBase {
    /// The base for `iccData` (nil: no profile) at `count` entries per channel.
    static func table(iccData: Data?, count: Int) -> GammaTable {
        guard let iccData, let vcgt = ProfileVCGT.parse(iccData: iccData) else { return .identity(count: count) }
        return vcgt.table(count: count)
    }
}
