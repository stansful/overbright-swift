// OverbrightPolicy/Ceilings/GainCeiling.swift — the ceilings per display and the interlock's one function.
// ARCHITECTURE.md §3.10, §5.3, §5.4, D5. Real bodies since WP0a except `sliderTop` (WP1).
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

    /// Safe nits for the class (nil for OLED, whose Safe cap is the relative ×1.3).
    public static func capNits(facts: DisplayFacts, isOLED: Bool) -> Double? {
        if isOLED { return nil }
        switch facts.panelClass {
        case .builtInXDR, .appleXDRExternal: return safeNitsAppleXDR
        case .hdrExternal: return facts.panelPeakNits.map { min(safeNitsAppleXDR, 0.6 * $0) }
        default: return nil
        }
    }
    /// The gain at the top of the boost half for this display and cap mode, at full SDR brightness (§5.3 table).
    /// Below 1.05 the boost half is disabled for that cap mode.
    public static func sliderTop(facts: DisplayFacts, capMode: CapMode, isOLED: Bool) -> Double {
        _ = (facts, capMode, isOLED)
        return 1   // WP1
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
        if taper, let ref = fullBrightnessHeadroom {
            let tapered = pow(g, taperExponent(headroom: h, fullBrightnessHeadroom: ref))
            if tapered < g { g = tapered; reason = .nearFullBrightnessOnly }
        }
        if capMode == .safe, sdrWhite == nil, safeBound == .worstCaseGrant,
           let cap = capNits(facts: facts, isOLED: isOLED), let peak = facts.panelPeakNits, peak > 0 {
            let bound = cap * h / peak          // sdrNow = grant ÷ H ≤ panelPeak ÷ H, so light ≤ cap
            if bound < g { g = bound; reason = .safeLimit }
        }
        let margin = FactorMath.headroomMargin * h
        if margin < g { g = margin; reason = .headroom }
        return LiveCap(gain: max(g, 1), reason: reason)
    }
}
