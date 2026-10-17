// OverbrightPolicy/Ceilings/GainCeiling.swift — the ceilings per display and the interlock's one function.
// ARCHITECTURE.md §3.10, §5.1, §5.3, §5.4, D5, D8. `liveCap` and the helpers since WP0a; `sliderTop`, `sdrMaxNits`
// and the OLED-override rule of `capNits` by WP1.
import Foundation
import OverbrightCore

/// Ceilings per display. Static ones in the reducer; live ones (`liveCap`) at write time in Boost's TableWriter.
public nonisolated enum GainCeiling {
    /// The Safe level of Apple XDR panels, in nits.
    public static let safeNitsAppleXDR = 1000.0
    /// The Safe cap of OLED displays (relative).
    public static let safeGainOLED = 1.3
    /// The cap while the thermal state is serious.
    public static let thermalSeriousGain = 1.2
    /// How Safe is bounded without a trusted SDR white (§5.4). WP16 may switch to `.sliderTopOnly` after H-G1.
    public enum SafeBound: Sendable {
        /// The live bound `capNits × H ÷ panelPeak` (default).
        case worstCaseGrant
        /// Only the static slider top.
        case sliderTopOnly
    }
    /// The Safe bound in use.
    public static let safeBound = SafeBound.worstCaseGrant
    /// Taper of "Add extra brightness only near full brightness": full gain while H ≤ 1.15 × the full-brightness
    /// headroom, none at ≥ 2 × (system brightness about halved). Tuned in WP16 (H-B1).
    public static let taperStart = 1.15
    /// See `taperStart`.
    public static let taperEnd = 2.0

    /// Share of an HDR external's panel peak that Safe allows: about the full-screen sustained level that the
    /// DisplayHDR tiers require (§5.3).
    public static let safeShareOfPanelPeak = 0.6
    /// A slider top below this disables the boost half for that cap mode; `sliderTop` then answers 1 (§5.3).
    public static let minimumUsefulTop = 1.05
    /// Classes whose boost half can exist (the others never boost, whatever the cap mode).
    static let boostClasses: Set<PanelClass> = [.builtInXDR, .appleXDRExternal, .hdrExternal, .oledExternal]

    /// Safe nits for the class (nil for OLED, whose Safe cap is the relative ×1.3). An OLED-class external that the
    /// user marked "Not OLED" is an other HDR external here (the override is applied before classifying, D8).
    public static func capNits(facts: DisplayFacts, isOLED: Bool) -> Double? {
        if isOLED { return nil }
        switch facts.panelClass {
        case .builtInXDR, .appleXDRExternal: return safeNitsAppleXDR
        case .hdrExternal, .oledExternal: return facts.panelPeakNits.map { min(safeNitsAppleXDR, safeShareOfPanelPeak * $0) }
        default: return nil
        }
    }
    /// The highest SDR white the user can pick without ambient boost (`sdrMax`, §5.1): the facts' value (the
    /// built-in's IORegistry value, an Apple XDR external's product value), and on another external without one its
    /// HDR-mode SDR white (`frameAverageSDRWhite`). Nil when neither is known.
    public static func sdrMaxNits(facts: DisplayFacts) -> Double? {
        let value = facts.sdrMaxNits ?? frameAverageSDRWhite(facts: facts)
        return value.flatMap { $0 > 0 ? $0 : nil }
    }
    /// An external's frame-average luminance as its HDR-mode SDR white (§5.1, §5.5; it matched WindowServer's SDR
    /// white on the measured OLED). Never on a built-in, and never on an Apple XDR external, where `MaxFrameAverage`
    /// is the full-screen sustained HDR level (1000 nits on the Pro Display XDR), not an SDR white.
    public static func frameAverageSDRWhite(facts: DisplayFacts) -> Double? {
        guard !facts.isBuiltIn, facts.panelClass != .appleXDRExternal, let nits = facts.panelFrameAverageNits,
              nits > 0 else { return nil }
        return nits
    }
    /// The gain at the top of the boost half for this display and cap mode, at full SDR brightness (§5.3 table):
    /// Peak `0.97 · peak / sdrMax`; Safe `min(capNits / sdrMax, Peak)`, on OLED `min(1.3, Peak)`. A top below 1.05
    /// disables the boost half for that cap mode and is answered as 1, as is a class that never boosts or a display
    /// whose panel peak or SDR maximum is unknown (no number we cannot back, DESIGN.md principle 2).
    public static func sliderTop(facts: DisplayFacts, capMode: CapMode, isOLED: Bool) -> Double {
        guard boostClasses.contains(facts.panelClass), let peak = facts.panelPeakNits, peak > 0,
              let sdrMax = sdrMaxNits(facts: facts) else { return 1 }
        let peakTop = FactorMath.headroomMargin * peak / sdrMax
        let top: Double
        switch capMode {
        case .peak:
            top = peakTop
        case .safe:
            if isOLED {
                top = min(safeGainOLED, peakTop)
            } else if let cap = capNits(facts: facts, isOLED: false) {
                top = min(cap / sdrMax, peakTop)
            } else {
                top = 1
            }
        }
        return top >= minimumUsefulTop ? top : 1
    }
    /// Seed of the full-brightness headroom (`panelPeak ÷ sdrMax`); Boost replaces it with the lowest ready H seen.
    public static func fullBrightnessHeadroomSeed(facts: DisplayFacts) -> Double? {
        guard let peak = facts.panelPeakNits, let sdr = facts.sdrMaxNits, sdr > 0 else { return nil }
        return peak / sdr
    }
    /// Exponent applied to the static gain by the taper: 1 near full brightness, 0 at about half brightness.
    public static func taperExponent(headroom: Double, fullBrightnessHeadroom: Double) -> Double {
        let r = headroom / max(fullBrightnessHeadroom, 1)
        return min(max((taperEnd - r) / (taperEnd - taperStart), 0), 1)
    }

    /// The interlock's answer for one write.
    public struct LiveCap: Hashable, Sendable {
        /// The light gain allowed now (≥ 1).
        public var gain: Double
        /// The live term that bound, if any (`nearFullBrightnessOnly`, `safeLimit` or `headroom`).
        public var reason: LimitReason?
    }
    /// The ONE function behind the interlock (§5.4): taper, the live Safe bound and 0.97 × H, in that order.
    public static func liveCap(staticGain: Double, reading: HeadroomReading, facts: DisplayFacts, capMode: CapMode,
                               isOLED: Bool, sdrWhite: SDRWhiteEstimate?, taper: Bool,
                               fullBrightnessHeadroom: Double?) -> LiveCap {
        let h = reading.current
        var g = staticGain
        var reason: LimitReason?
        func bind(_ term: Double, _ why: LimitReason) {
            guard term < g else { return }
            if term < g * (1 - bindingTolerance) { reason = why }
            g = term
        }
        if taper, let ref = fullBrightnessHeadroom {
            bind(pow(g, taperExponent(headroom: h, fullBrightnessHeadroom: ref)), .nearFullBrightnessOnly)
        }
        if capMode == .safe, sdrWhite == nil, safeBound == .worstCaseGrant,
           let cap = capNits(facts: facts, isOLED: isOLED), let peak = facts.panelPeakNits, peak > 0 {
            bind(cap * h / peak, .safeLimit)          // sdrNow = grant ÷ H ≤ panelPeak ÷ H, so light ≤ cap
        }
        bind(FactorMath.headroomMargin * h, .headroom)
        return LiveCap(gain: max(g, 1), reason: reason)
    }
    /// A live term is reported as binding only when it lies below the gain by more than rounding: a reading exactly
    /// at the grant makes Peak's top and `0.97 × H` equal up to the last bit, which is not a limit. The gain is the
    /// exact minimum either way.
    public static let bindingTolerance = 1e-9
}
