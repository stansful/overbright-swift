// OverbrightCore/Model/Displays/DisplayFacts.swift — everything Overbright knows about one display. ARCHITECTURE.md §3.2, D8.
import CoreGraphics

/// Everything Overbright knows about one display, refreshed on every reconfiguration.
public nonisolated struct DisplayFacts: Hashable, Sendable {
    /// Key and current CoreGraphics ID.
    public var ref: DisplayRef
    /// `NSScreen.localizedName`. For the UI only; no logic may compare it (D8).
    public var name: String
    /// `CGDisplayIsBuiltin`.
    public var isBuiltIn: Bool
    /// Member of a hardware mirror set that does NOT own the set's NSScreen (`CGDisplayMirrorsDisplay` ≠ 0).
    /// It has its own table but no headroom reading of its own: dim only (verdict `.mirrored`).
    public var isMirrored: Bool
    /// `CGDisplayGammaTableCapacity`; 0 means the display has no transfer table.
    public var gammaCapacity: Int
    /// `CGDisplayVendorNumber` (EDID manufacturer ID); nil when unknown.
    public var vendorID: UInt32?
    /// `CGDisplayModelNumber`; nil when unknown.
    public var productID: UInt32?
    /// IORegistry `SupportsPQEOTF` (externals); nil when unknown.
    public var supportsPQ: Bool?
    /// Panel maximum luminance in nits (built-in: `EDRPotentialHeadroom` × 100; external: DisplayAttributes Luminance Max,
    /// else an Apple XDR product's; without either, potential × 100 on a display with extra range, D8).
    public var panelPeakNits: Double?
    /// External: DisplayAttributes Luminance MaxFrameAverage (the HDR-mode SDR white on the measured OLED; on an
    /// Apple XDR external the full-screen sustained HDR level, never an SDR white).
    public var panelFrameAverageNits: Double?
    /// External: DisplayAttributes Luminance Min.
    public var panelMinNits: Double?
    /// Highest SDR white the user can select without ambient boost (built-in `user-accessible-max-nits`; Apple XDR
    /// external: the product's, 500 or 1000 nits).
    public var sdrMaxNits: Double?
    /// `NSScreen.safeAreaInsets.top > 0`.
    public var hasNotch: Bool
    /// The hardware class (D8).
    public var panelClass: PanelClass
    /// Facts as read by `OverbrightDisplays` (or a fixture); IORegistry inputs are optional.
    public init(ref: DisplayRef, name: String, isBuiltIn: Bool, isMirrored: Bool = false, gammaCapacity: Int,
                vendorID: UInt32? = nil, productID: UInt32? = nil, supportsPQ: Bool? = nil,
                panelPeakNits: Double? = nil, panelFrameAverageNits: Double? = nil, panelMinNits: Double? = nil,
                sdrMaxNits: Double? = nil, hasNotch: Bool = false, panelClass: PanelClass) {
        self.ref = ref; self.name = name; self.isBuiltIn = isBuiltIn; self.isMirrored = isMirrored
        self.gammaCapacity = gammaCapacity; self.vendorID = vendorID; self.productID = productID
        self.supportsPQ = supportsPQ; self.panelPeakNits = panelPeakNits
        self.panelFrameAverageNits = panelFrameAverageNits; self.panelMinNits = panelMinNits
        self.sdrMaxNits = sdrMaxNits; self.hasNotch = hasNotch; self.panelClass = panelClass
    }
}
