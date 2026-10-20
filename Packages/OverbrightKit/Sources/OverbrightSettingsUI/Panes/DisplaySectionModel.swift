// OverbrightSettingsUI/Panes/DisplaySectionModel.swift — everything one display's section of Settings ▸ Displays shows,
// derived without a view from the engine's status, the display's facts, its preferences and the Mac (DESIGN.md §7.4,
// §5.5, §12.1; ARCHITECTURE.md §5.2–§5.4, D8). The verdict is the reducer's when the engine has classified the display,
// else Policy's classifier over the same inputs; the slider's top, presets and halves follow the panel's rules
// (PanelUI's `DisplayCardModel`, which an L2 module cannot import). Pure: the tests build it from fixtures.
import OverbrightCore
import OverbrightDesign
import OverbrightPolicy

/// The derived state of one display's section.
struct DisplaySectionModel {
    /// The display.
    let key: DisplayKey
    /// The name macOS gives it (for the header and VoiceOver; never compared).
    let name: String
    /// Its facts, nil while the directory does not list it.
    let facts: DisplayFacts?
    /// Its stored preferences (the defaults when none are stored).
    let preferences: DisplayPreferences
    /// The verdict, advisories and class defaults.
    let eligibility: EligibilityResult
    /// The display counts as OLED (the override, else the IORegistry minimum luminance).
    let isOLED: Bool
    /// What Automatic detected (the Display type pop-up's "Automatic (OLED)").
    let detectedOLED: Bool
    /// The level the slider shows (the linked one while levels are linked).
    let level: LevelPosition
    /// "Same level on all displays" is on.
    let isLinked: Bool
    /// The light gain at the top of the boost half for the display's cap mode.
    let top: Double
    /// The Peak top at full brightness.
    let peakTop: Double
    /// The presets shown on this display.
    let presets: [LevelPreset]
    /// Where macOS lets the thumb stop now; nil without a reading.
    let allowedNow: Double?
    /// The readout's numbers.
    let readout: ReadoutValues
    /// The calibration record still applies (same macOS build and method, the potential within 5 % when known).
    let calibrationIsValid: Bool
    /// The macOS version of this Mac ("27.0.1"), the version a valid record was made on.
    let osVersion: String
    /// Overbright is on, and no pause the user set holds it.
    let isActive: Bool
    /// The decision holds a boost level at Standard (a guard, a pause or a stop).
    let isHeld: Bool

    /// A top below this disables the boost half for the cap mode (ARCHITECTURE.md §5.3).
    static let minimumTop = 1.05
    /// Up to this Max gain the value text adds "small gain on this display".
    static let smallGainTop = 1.3

    /// The section of `status`'s display.
    init(status: DisplayStatus, facts: DisplayFacts?, preferences: DisplayPreferences, isMasterOn: Bool, isPaused: Bool,
         linkLevels: Bool, linkedLevel: LevelPosition, taper: Bool, machine: MachineIdentity) {
        key = status.key
        name = facts?.name ?? status.name
        self.facts = facts
        self.preferences = preferences
        let override = preferences.oled
        detectedOLED = facts.map { EligibilityClassifier.isOLED($0, override: .automatic) } ?? false
        isOLED = facts.map { EligibilityClassifier.isOLED($0, override: override) } ?? (override == .oled)
        if let decided = status.decision?.eligibility {
            eligibility = decided
        } else if let facts {
            eligibility = EligibilityClassifier.classify(facts, preferences: preferences, reading: status.lastReading,
                                                         machine: machine)
        } else {
            eligibility = EligibilityResult(verdict: .checking, advisories: [], defaultBoostEnabled: false,
                                            defaultMechanism: .table)
        }
        // The mechanism the display uses now (the reducer's, else the preference over the class default).
        let mechanism = status.decision?.mechanism
            ?? EligibilityClassifier.effectiveMechanism(preferences.mechanism, defaultMechanism: eligibility.defaultMechanism)
        isLinked = linkLevels
        level = linkLevels ? linkedLevel : preferences.level
        top = Self.top(verdict: eligibility.verdict, facts: facts, capMode: preferences.capMode, isOLED: isOLED)
        peakTop = Self.top(verdict: eligibility.verdict, facts: facts, capMode: .peak, isOLED: isOLED)
        presets = PresetVisibility.visiblePresets(top: top)
        readout = Readout.values(for: status, isMasterOn: isMasterOn)
        calibrationIsValid = Self.isValid(preferences.calibration, mechanism: mechanism, machine: machine,
                                          potential: status.lastReading?.potential)
        osVersion = machine.osPatch > 0 ? "\(machine.osMajor).\(machine.osMinor).\(machine.osPatch)"
            : "\(machine.osMajor).\(machine.osMinor)"
        isActive = isMasterOn && !isPaused
        isHeld = Self.isHeld(level: level, decision: status.decision)
        allowedNow = Self.allowedNow(status: status, isMasterOn: isMasterOn, facts: facts, top: top,
                                     capMode: preferences.capMode, isOLED: isOLED, taper: taper)
    }

    // MARK: What the section shows

    /// The verdict.
    var verdict: DisplayVerdict { eligibility.verdict }
    /// The display can show extra brightness at all (the switch, the limit and calibration rows).
    var canBoost: Bool { verdict.allowsBoost }
    /// The display can be dimmed (or would use the overlay): the level row.
    var canAdjust: Bool { verdict.allowsBoost || verdict.allowsDim }
    /// The per-display switch: the preference, else the class default.
    var boostEnabled: Bool { preferences.boostEnabled ?? eligibility.defaultBoostEnabled }
    /// The display is an external one (the Display type row).
    var isExternal: Bool { !(facts?.isBuiltIn ?? true) && facts?.panelClass != .virtualDisplay }
    /// Max is at most ×1.3 here: the value text adds "small gain on this display".
    var hasSmallGain: Bool { top >= Self.minimumTop && top <= Self.smallGainTop + 1e-9 }

    /// How the slider's boost half draws (the reason of an unavailable half is already in words).
    func boostHalf(oledIdleMinutes: Int) -> BoostHalfState {
        if !verdict.allowsBoost {
            return .unavailable(reason: VerdictText.make(verdict, advisories: [], lastGrant: nil,
                                                         capMode: preferences.capMode, oledIdleMinutes: oledIdleMinutes,
                                                         in: .app).sentence)
        }
        if top < Self.minimumTop {
            if preferences.capMode == .safe && peakTop >= Self.minimumTop {
                return .unavailable(reason: SafeLimitText.addsNothing())
            }
            return .unavailable(reason: VerdictText.make(.noGainAtFullBrightness(peakGain: peakTop), advisories: [],
                                                         lastGrant: nil).sentence)
        }
        if !boostEnabled { return .switchedOff }
        return isActive && !isHeld ? .active : .inactive
    }

    /// The value text of a slider position (the canonical text, with "small gain on this display" when Max is low).
    func valueText(at position: LevelPosition) -> String {
        let text = ValueText.forLevel(position, top: top, presets: presets, isEstimate: readout.isEstimate).text
        guard position.isBoost, hasSmallGain, !text.isEmpty else { return text }
        return CopyFormat.parts(text, ValueText.smallGain())
    }

    /// The VoiceOver value of a slider position: the spoken canonical text, with "small gain on this display" too.
    func spokenValue(at position: LevelPosition) -> String {
        let spoken = ValueText.forLevel(position, top: top, presets: presets, isEstimate: readout.isEstimate).accessibilityText
        guard position.isBoost, hasSmallGain, !spoken.isEmpty else { return spoken }
        return CopyFormat.spokenParts(spoken, ValueText.smallGain())
    }

    /// The Safe sentence of this display (the Limit footnote, DESIGN.md §12.2).
    var safeSentence: String {
        let safeTop: Double? = if case .supported(let safeGain, _) = verdict { safeGain } else { nil }
        return SafeLimitText(panelClass: facts?.panelClass ?? .sdrExternal, isOLED: isOLED, safeTop: safeTop,
                             sdrWhiteNits: preferences.calibration?.measuredSDRWhiteNits).sentence()
    }

    // MARK: Derivations (pure)

    /// The top of the boost half: the verdict's figures, else `GainCeiling.sliderTop` from the facts, else no boost.
    static func top(verdict: DisplayVerdict, facts: DisplayFacts?, capMode: CapMode, isOLED: Bool) -> Double {
        switch verdict {
        case let .supported(safeGain, peakGain): capMode == .safe ? (safeGain ?? 1) : peakGain
        case let .noGainAtFullBrightness(peakGain): peakGain
        default: facts.map { GainCeiling.sliderTop(facts: $0, capMode: capMode, isOLED: isOLED) } ?? 1
        }
    }

    /// A boost level whose decision is not a boost: a guard, a pause or a stop holds it at Standard.
    static func isHeld(level: LevelPosition, decision: DisplayDecision?) -> Bool {
        guard level.isBoost, let decision else { return false }
        if case .boost = decision.target { return false }
        return true
    }

    /// The allowed-now marker: the live cap of the top gain from the engine's last reading, while boosting.
    static func allowedNow(status: DisplayStatus, isMasterOn: Bool, facts: DisplayFacts?, top: Double, capMode: CapMode,
                           isOLED: Bool, taper: Bool) -> Double? {
        guard isMasterOn, let reading = status.lastReading, let facts, top >= minimumTop else { return nil }
        switch status.phase {
        case .gating, .ramping, .boosted: break
        default: return nil
        }
        let cap = GainCeiling.liveCap(staticGain: top, reading: reading, facts: facts, capMode: capMode, isOLED: isOLED,
                                      sdrWhite: status.sdrWhite, taper: taper,
                                      fullBrightnessHeadroom: GainCeiling.fullBrightnessHeadroomSeed(facts: facts))
        return min(cap.gain, top)
    }

    /// A record still applies while the macOS build and the method match and, when a reading is there, the potential is
    /// within 5 % of the one measured (ARCHITECTURE.md §5.2, DESIGN.md §9 "Validity"). Without a reading the potential
    /// cannot be compared, so the record is not called stale for that alone.
    static func isValid(_ record: CalibrationRecord?, mechanism: Mechanism, machine: MachineIdentity,
                        potential: Double?) -> Bool {
        guard let record else { return false }
        guard record.mechanism == mechanism, record.osBuild == machine.osBuild else { return false }
        guard let potential else { return true }
        return abs(potential - record.potentialAtTest)
            <= EligibilityClassifier.calibrationPotentialTolerance * record.potentialAtTest
    }
}
