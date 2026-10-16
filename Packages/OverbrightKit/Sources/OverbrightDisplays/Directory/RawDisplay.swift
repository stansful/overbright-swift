// OverbrightDisplays/Directory/RawDisplay.swift — the CoreGraphics and NSScreen facts of one online display, as read.
// ARCHITECTURE.md §3.2, §10.4, D8. `CoreGraphicsDisplayReader` fills it on the main actor; `DisplayFactsBuilder` turns
// it (with `IORegistryFacts`) into `DisplayFacts`. Tests build it directly.
import CoreGraphics
import OverbrightCore

/// One online display before classification.
nonisolated struct RawDisplay: Hashable, Sendable {
    /// What its own NSScreen says (a hardware-mirror member and a display in transition have none).
    struct Screen: Hashable, Sendable {
        /// `NSScreen.localizedName` (UI only, D8).
        var name: String
        /// `maximumPotentialExtendedDynamicRangeColorComponentValue`.
        var potential: Double
        /// `safeAreaInsets.top > 0`.
        var hasNotch: Bool
    }

    /// The transient CoreGraphics ID.
    var id: CGDirectDisplayID
    /// `DisplayKey.of(id)`.
    var key: DisplayKey
    /// `CGDisplayIsBuiltin`.
    var isBuiltIn: Bool
    /// `CGDisplayGammaTableCapacity`.
    var gammaCapacity: Int
    /// The transfer table could be read (`GammaPort.read`); false for a display whose read fails.
    var tableReadable: Bool
    /// `CGDisplayVendorNumber` (`0x756e6b6e` "unkn" is macOS's placeholder for displays without a real EDID vendor).
    var vendor: UInt32
    /// `CGDisplayModelNumber`.
    var model: UInt32
    /// `CGDisplaySerialNumber`.
    var serial: UInt32
    /// `CGDisplayMirrorsDisplay`: the master of its mirror set, or `kCGNullDirectDisplay`.
    var mirrorsDisplay: CGDirectDisplayID
    /// Its own NSScreen, nil when it has none.
    var screen: Screen?
}
