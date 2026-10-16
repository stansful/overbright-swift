// OverbrightPolicy/Eligibility/EligibilityClassifier.swift — what a display can do (D8). ARCHITECTURE.md §3.10, §5.2,
// §5.3, §6.1 steps 1 and 4, §7.5; DESIGN.md §12.1. Locale-independent: names are never compared, and every IORegistry
// input is optional (a panel peak or SDR maximum that no fallback supplies gives a top of 1 and the verdict
// `.checking`, never a guess and never a "little gain" claim).
import OverbrightCore

/// D8 classifier: tolerant comparisons, no name strings in logic, IORegistry inputs optional. `preferences` carries
/// the OLED override and the calibration record; `machine` decides `compatibilityModeAdvised`.
public nonisolated enum EligibilityClassifier {
    /// Tolerance of every comparison with a headroom value (potential, reference).
    public static let epsilon = 0.01
    /// Potential at or below this (+ ε) has no extra range: HDR is off or the preset is SDR.
    public static let sdrPotential = 1.0
    /// Potential at or below this (+ ε) is an LCD-class panel without useful range.
    public static let lcdPotential = 2.0
    /// A preset whose peak (potential × 100 nits) is below this share of the panel peak "limits HDR".
    public static let presetLimitShare = 0.9
    /// Nits per unit of potential (`maximumPotential…` ≈ preset peak ÷ 100 nits, D8).
    public static let nitsPerPotential = 100.0
    /// Peak gain at full brightness below this is "little gain".
    public static let minimumPeakGain = 1.1
    /// IORegistry minimum luminance at or below this is self-emissive: OLED (D8).
    public static let oledMinimumNits = 0.005
    /// Calibration records stay valid while the potential is within this share of the one measured (§5.2).
    public static let calibrationPotentialTolerance = 0.05

    /// The verdict, advisories and class defaults of one display.
    public static func classify(_ facts: DisplayFacts, preferences: DisplayPreferences, reading: HeadroomReading?,
                                machine: MachineIdentity) -> EligibilityResult {
        let oled = isOLED(facts, override: preferences.oled)
        let verdict = verdict(facts, isOLED: oled, reading: reading)
        let advised = CompatibilityModels.tableWritesIgnored(machine)
        let potential = reading?.potential
        let notBrighter = preferences.calibration.map { record in
            record.outcome == .notBrighter
                && isValid(record, mechanism: .table, machine: machine, potential: potential)
        } ?? false
        let defaultMechanism: Mechanism = advised || notBrighter ? .overlay : .table
        let mechanism = effectiveMechanism(preferences.mechanism, defaultMechanism: defaultMechanism)

        var advisories: [Advisory] = []
        if advised && (verdict.allowsBoost || verdict.allowsDim) { advisories.append(.compatibilityModeAdvised) }
        if verdict.allowsBoost {
            if oled { advisories.append(.oledCare) }
            if facts.isBuiltIn && facts.panelClass == .builtInXDR && machine.osMajor >= 26 {
                advisories.append(.autoBrightnessInteracts)
            }
            if !hasValidCalibration(preferences.calibration, mechanism: mechanism, machine: machine,
                                    potential: potential) {
                advisories.append(.notCalibrated)
            }
        }
        let classDefault = !oled && (facts.panelClass == .builtInXDR || facts.panelClass == .appleXDRExternal)
        return EligibilityResult(verdict: verdict, advisories: advisories, defaultBoostEnabled: classDefault,
                                 defaultMechanism: defaultMechanism)
    }

    /// The display is treated as OLED: the user's override, else an `oledExternal` class or an external whose
    /// IORegistry minimum luminance is self-emissive (≤ 0.005 nits), except an Apple XDR external, whose mini-LED
    /// black level can read that low too (the panel classifier checks XDR first for the same reason). Never decided
    /// by name.
    public static func isOLED(_ facts: DisplayFacts, override: OLEDOverride) -> Bool {
        switch override {
        case .oled: return true
        case .notOLED: return false
        case .automatic:
            if facts.panelClass == .oledExternal { return true }
            guard !facts.isBuiltIn, facts.panelClass != .appleXDRExternal, let minimum = facts.panelMinNits else {
                return false
            }
            return minimum <= oledMinimumNits
        }
    }

    /// The mechanism a display uses: an explicit preference wins; `automatic` takes the class default (§6.1 step 4).
    public static func effectiveMechanism(_ preference: MechanismPreference, defaultMechanism: Mechanism) -> Mechanism {
        switch preference {
        case .automatic: defaultMechanism
        case .table: .table
        case .overlay: .overlay
        }
    }

    /// A record that confirmed a domain (`encoded` or `linear`) and still applies: same mechanism, same OS build, and
    /// a potential within ±5 % of the one measured (§5.2). Readouts are estimates without one (DESIGN.md §5.6).
    public static func hasValidCalibration(_ record: CalibrationRecord?, mechanism: Mechanism, machine: MachineIdentity,
                                           potential: Double?) -> Bool {
        guard let record, record.outcome == .encoded || record.outcome == .linear else { return false }
        return isValid(record, mechanism: mechanism, machine: machine, potential: potential)
    }

    // MARK: Verdict (D8 order)

    private static func verdict(_ facts: DisplayFacts, isOLED: Bool, reading: HeadroomReading?) -> DisplayVerdict {
        if facts.panelClass == .virtualDisplay { return .virtualDisplay }
        if facts.gammaCapacity <= 0 { return .noGammaTable }
        if facts.isMirrored { return .mirrored }
        guard let reading, reading.potential >= sdrPotential - epsilon else { return .checking }
        if reading.reference > epsilon { return .referencePreset }
        if reading.potential <= sdrPotential + epsilon { return noRangeVerdict(facts) }
        if reading.potential <= lcdPotential + epsilon { return .lcdClass }
        let presetPeak = reading.potential * nitsPerPotential
        if let panelPeak = facts.panelPeakNits, presetPeak < presetLimitShare * panelPeak {
            return .presetLimits(presetPeakNits: presetPeak, panelPeakNits: panelPeak)
        }
        // No backed number: the facts' fallbacks are exhausted (§9.2 rule 6), so no "little gain" claim either.
        // The facts are rebuilt at every reconfiguration and screen-parameter change, which re-checks.
        if GainCeiling.boostClasses.contains(facts.panelClass), !GainCeiling.hasBackedTop(facts: facts) {
            return .checking
        }
        let peakTop = GainCeiling.sliderTop(facts: facts, capMode: .peak, isOLED: isOLED)
        if peakTop < minimumPeakGain { return .noGainAtFullBrightness(peakGain: peakTop) }
        let safeTop = GainCeiling.sliderTop(facts: facts, capMode: .safe, isOLED: isOLED)
        return .supported(safeGain: safeTop > 1 ? safeTop : nil, peakGain: peakTop)
    }

    /// Potential ≤ 1: HDR is off on an external that supports PQ, the preset is SDR on a built-in or XDR panel, an
    /// LCD built-in has no range at all, and any other external is SDR.
    private static func noRangeVerdict(_ facts: DisplayFacts) -> DisplayVerdict {
        switch facts.panelClass {
        case .builtInXDR, .appleXDRExternal: return .switchPreset
        case .builtInLCD: return .lcdClass
        default:
            if facts.isBuiltIn { return .lcdClass }
            return facts.supportsPQ ?? (facts.panelClass == .hdrExternal) ? .turnOnHDR : .notHDR
        }
    }

    private static func isValid(_ record: CalibrationRecord, mechanism: Mechanism, machine: MachineIdentity,
                                potential: Double?) -> Bool {
        guard record.mechanism == mechanism, record.osBuild == machine.osBuild, let potential else { return false }
        return abs(potential - record.potentialAtTest) <= calibrationPotentialTolerance * record.potentialAtTest
    }
}
