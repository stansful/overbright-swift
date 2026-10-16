// OverbrightDisplays/Directory/PanelClassifier.swift — the coarse hardware class of a display. ARCHITECTURE.md §3.2
// (`PanelClass`), §10.4, D8. Pure, from public facts only (built-in flag, vendor, IORegistry luminance and PQ support,
// NSScreen potential as the fallback), never from names. The user's OLED override is applied by Policy's
// `EligibilityClassifier`, which reads `DisplayPreferences`; this class is the automatic one.
import OverbrightCore

/// Derives `PanelClass`.
nonisolated enum PanelClassifier {
    /// Apple's EDID vendor ID (`CGDisplayVendorNumber` of the built-in, Pro Display XDR and Studio Display XDR).
    static let appleVendor: UInt32 = 0x0610
    /// D8's tolerance for comparisons against potential thresholds.
    static let epsilon = 0.01
    /// A built-in panel above this potential is an XDR panel (R5: LCD built-ins report 2.0).
    static let lcdPotentialLimit = 2.0
    /// A minimum luminance at or below this is a self-emissive (OLED) panel (D8).
    static let oledMinimumNits = 0.005
    /// An Apple external at or above this peak is an XDR display (§3.2).
    static let appleXDRPeakNits = 1000.0

    /// The class of a display with these facts. `potential` is the panel's own potential when the IORegistry knows it
    /// (built-in `EDRPotentialHeadroom`), else NSScreen's (which depends on the preset).
    static func classify(isVirtual: Bool, isBuiltIn: Bool, vendor: UInt32?, potential: Double?, peakNits: Double?,
                         minNits: Double?, supportsPQ: Bool?) -> PanelClass {
        if isVirtual { return .virtualDisplay }
        if isBuiltIn { return (potential ?? 1) > lcdPotentialLimit + epsilon ? .builtInXDR : .builtInLCD }
        // Apple XDR first: its mini-LED EDID may report a black level an OLED rule would match.
        if vendor == appleVendor, let peakNits, peakNits >= appleXDRPeakNits { return .appleXDRExternal }
        if let minNits, minNits <= oledMinimumNits { return .oledExternal }
        switch supportsPQ {
        case true?: return .hdrExternal
        case false?: return .sdrExternal
        case nil: return (potential ?? 1) > 1 + epsilon ? .hdrExternal : .sdrExternal
        }
    }
}
