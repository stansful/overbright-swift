// OverbrightDisplays/Registry/BuiltInPanelFacts.swift — what the IORegistry says about the built-in panel.
// ARCHITECTURE.md §3.2 (`DisplayFacts.panelPeakNits`, `sdrMaxNits`), §10.4, D8; docs/research/display-facts.md §5.
// Pure parsing of the device tree's `backlight` node and `AppleARMBacklight`'s `IODisplayParameters` (Apple silicon).
// Every key is undocumented and optional; an Intel Mac or an unknown layout yields nil and the facts fall back to
// NSScreen and CoreGraphics (§9.2 rule 6).
import Foundation

/// The built-in panel's capability and SDR range, from the IORegistry.
public nonisolated struct BuiltInPanelFacts: Hashable, Sendable {
    /// Device tree `backlight` ▸ `EDRPotentialHeadroom` (16.16 fixed point): 16.0 on the M4 Max's XDR panel.
    public var potentialHeadroom: Double?
    /// Device tree `backlight` ▸ `user-accessible-max-nits` (16.16): the highest SDR white the user can select without
    /// ambient boost (600 on the M4 Max).
    public var sdrMaxNits: Double?
    /// `AppleARMBacklight` ▸ `IODisplayParameters` ▸ `BrightnessMilliNits.max` (≈ 1 600 000 on the M4 Max).
    /// Diagnostics only: nothing documents what it measures (§5.5 trusts `BrightnessMilliNits` only after H-N1), so
    /// it never stands in for the panel peak.
    public var backlightMaxMilliNits: Double?
    /// `BrightnessMilliNits.value` at the time of the read; diagnostics only (`backlightMilliNits`, H-N1).
    public var backlightMilliNits: Double?

    /// Facts with the given values.
    public init(potentialHeadroom: Double? = nil, sdrMaxNits: Double? = nil, backlightMaxMilliNits: Double? = nil,
                backlightMilliNits: Double? = nil) {
        self.potentialHeadroom = potentialHeadroom; self.sdrMaxNits = sdrMaxNits
        self.backlightMaxMilliNits = backlightMaxMilliNits; self.backlightMilliNits = backlightMilliNits
    }

    /// The panel's maximum luminance: `EDRPotentialHeadroom × 100` (§3.2), nil without it (the facts builder then
    /// falls back to NSScreen's potential, D8). Never the backlight's `BrightnessMilliNits.max`: a value below the
    /// true peak would loosen the Safe bound.
    public var panelPeakNits: Double? {
        guard let potentialHeadroom, potentialHeadroom > 0 else { return nil }
        return potentialHeadroom * 100
    }

    /// The facts in `backlight` (the device-tree node's properties) and `displayParameters` (`AppleARMBacklight`'s
    /// `IODisplayParameters`); nil when neither carries a known key.
    static func parse(backlight: [String: Any]?, displayParameters: [String: Any]?) -> BuiltInPanelFacts? {
        let milliNits = IORegistryValue.dictionary(displayParameters?["BrightnessMilliNits"])
        let facts = BuiltInPanelFacts(
            potentialHeadroom: IORegistryValue.fixedPointData(backlight?["EDRPotentialHeadroom"]).flatMap(positive),
            sdrMaxNits: IORegistryValue.fixedPointData(backlight?["user-accessible-max-nits"]).flatMap(positive),
            backlightMaxMilliNits: IORegistryValue.integer(milliNits?["max"]).map(Double.init).flatMap(positive),
            backlightMilliNits: IORegistryValue.integer(milliNits?["value"]).map(Double.init))
        return facts == BuiltInPanelFacts() ? nil : facts
    }

    private static func positive(_ value: Double) -> Double? { value.isFinite && value > 0 ? value : nil }
}
