// OverbrightPanelUI/Card/DisplayCardModel.swift — everything one display card shows, derived without a view from the
// engine's status, the display's facts and its preferences. DESIGN.md §5.4–§5.7, §5.10, §5.11; ARCHITECTURE.md §5.3,
// §5.4, §6.2. The card, the status menu and the tests share it, so the slider's top, the shown presets, the marker and
// the chip are decided once.
import OverbrightCore
import OverbrightPolicy

/// The derived state of one display's card.
public struct DisplayCardModel: Hashable {
    /// How the boost half of the slider draws (the localized reason of `unavailable` is added by the view).
    public enum BoostHalf: Hashable {
        /// Extra light is (or is about to be) on screen.
        case active
        /// Overbright is off or paused, or a guard holds the boost: nothing is brighter.
        case inactive
        /// Extra brightness is off for this display (opt-in displays, "Don't Use on This Display").
        case switchedOff
        /// Boosting is impossible: the verdict forbids it, or the top of this cap mode is below ×1.05.
        case unavailable(Unavailable)
    }

    /// Why the boost half cannot be used.
    public enum Unavailable: Hashable {
        /// The verdict forbids boosting (its sentence is the help tag).
        case verdict(DisplayVerdict)
        /// Safe adds less than ×1.05 here; Peak would add more.
        case safeLimitReached
        /// Even Peak adds less than ×1.05.
        case littleGain
    }

    /// The display.
    public var key: DisplayKey
    /// `DisplayStatus.name`, for VoiceOver and the OLED notice (the card's title comes from `CardTitles`).
    public var name: String
    /// The stored level (the linked level while "Same level on all displays" is on).
    public var level: LevelPosition
    /// "Same level on all displays" is on.
    public var isLinked: Bool
    /// The display's cap mode.
    public var capMode: CapMode
    /// The display counts as OLED (class or override).
    public var isOLED: Bool
    /// The verdict, once the reducer has classified the display.
    public var verdict: DisplayVerdict?
    /// The light gain at the top of the boost half (`GainCeiling.sliderTop`, or the verdict's figure).
    public var top: Double
    /// The Peak top at full brightness (the "can reach" figure of the marker's help tag).
    public var peakTop: Double
    /// Where macOS lets the thumb stop now; nil when there is no reading (off, never armed).
    public var allowedNow: Double?
    /// The presets shown on this display.
    public var presets: [LevelPreset]
    /// The dim half works (a transfer table or the overlay).
    public var dimEnabled: Bool
    /// The per-display switch of extra brightness (preference, else the class default).
    public var boostEnabled: Bool
    /// How the boost half draws.
    public var boostHalf: BoostHalf
    /// The per-display reason the chip shows (nil: the engine phase alone decides, or no chip).
    public var chipReason: LimitReason?
    /// The engine phase (Preparing… and No extra range win over every reason).
    public var phase: EnginePhase
    /// Failed tries in this session (the No extra range chip changes after two).
    public var failedTries: Int
    /// The display runs in Compatibility mode (the caption line under the readout).
    public var isCompatibilityMode: Bool
    /// The readout's numbers (Policy's `Readout.values`).
    public var readout: ReadoutValues
    /// The verdict's advisories.
    public var advisories: [Advisory]

    /// The derived state of `status`'s card.
    /// - Parameters:
    ///   - status: what the engine publishes for the display.
    ///   - isMasterOn: the master switch.
    ///   - isPaused: a pause the user set is active.
    ///   - banner: the banner the panel shows (a card shows no chip for the reason the banner already says).
    ///   - facts: the display's facts (nil while the directory does not list it).
    ///   - preferences: its stored preferences.
    ///   - linkLevels / linkedLevel: "Same level on all displays".
    ///   - taper: "Add extra brightness only near full brightness".
    public init(status: DisplayStatus, isMasterOn: Bool, isPaused: Bool, banner: Banner?, facts: DisplayFacts?,
                preferences: DisplayPreferences, linkLevels: Bool, linkedLevel: LevelPosition, taper: Bool) {
        key = status.key
        name = status.name
        isLinked = linkLevels
        level = linkLevels ? linkedLevel : preferences.level
        capMode = preferences.capMode
        isOLED = Self.isOLED(facts: facts, override: preferences.oled)
        let eligibility = status.decision?.eligibility
        verdict = eligibility?.verdict
        advisories = eligibility?.advisories ?? []
        phase = status.phase
        failedTries = status.failedTries
        isCompatibilityMode = (status.decision?.mechanism ?? status.mechanism) == .overlay
        readout = Readout.values(for: status, isMasterOn: isMasterOn)

        top = Self.top(verdict: verdict, facts: facts, capMode: capMode, isOLED: isOLED)
        peakTop = Self.top(verdict: verdict, facts: facts, capMode: .peak, isOLED: isOLED)
        presets = PresetVisibility.visiblePresets(top: top)
        dimEnabled = verdict?.allowsDim ?? Self.hasTable(facts)
        boostEnabled = preferences.boostEnabled ?? eligibility?.defaultBoostEnabled ?? Self.classDefault(facts)

        let canBoostByVerdict = verdict?.allowsBoost ?? (facts != nil && facts?.panelClass != .virtualDisplay)
        if let verdict, !verdict.allowsBoost {
            boostHalf = .unavailable(.verdict(verdict))
        } else if !canBoostByVerdict || top < Self.minimumTop {
            boostHalf = .unavailable(peakTop >= Self.minimumTop && capMode == .safe ? .safeLimitReached : .littleGain)
        } else if !boostEnabled {
            boostHalf = .switchedOff
        } else if !isMasterOn || isPaused || Self.isHeld(level: level, decision: status.decision) {
            boostHalf = .inactive
        } else {
            boostHalf = .active
        }
        allowedNow = Self.allowedNow(status: status, isMasterOn: isMasterOn, facts: facts, top: top,
                                     capMode: capMode, isOLED: isOLED, taper: taper)
        chipReason = CardChip.reason(decision: status.decision, key: status.key, banner: banner, isMasterOn: isMasterOn)
    }

    /// A top below this disables the boost half for the cap mode (ARCHITECTURE.md §5.3).
    public static let minimumTop = 1.05
    /// Up to this Max gain the value tag adds "small gain on this display" (ARCHITECTURE.md §5.3; DESIGN.md §5.13's
    /// `small-gain` state is the OLED's Safe top of exactly ×1.3).
    public static let smallGainTop = 1.3

    /// Max is at most ×1.3 on this display.
    public var hasSmallGain: Bool { top <= Self.smallGainTop + 1e-9 && top >= Self.minimumTop }

    /// The display failed (Try Again belongs in the context menu).
    public var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }

    /// The display can be calibrated (it can boost).
    public var canCalibrate: Bool { verdict?.allowsBoost ?? false }

    /// The display can boost at all on this Mac (whatever the switch says).
    public var canBoost: Bool {
        if case .unavailable = boostHalf { return false }
        return true
    }

    // MARK: Derivations

    /// The top of the boost half: the verdict's figures (the reducer's ceilings at full brightness), else
    /// `GainCeiling.sliderTop` from the facts, else no boost.
    static func top(verdict: DisplayVerdict?, facts: DisplayFacts?, capMode: CapMode, isOLED: Bool) -> Double {
        switch verdict {
        case let .supported(safeGain, peakGain)?: return capMode == .safe ? (safeGain ?? 1) : peakGain
        case let .noGainAtFullBrightness(peakGain)?: return peakGain
        default: return facts.map { GainCeiling.sliderTop(facts: $0, capMode: capMode, isOLED: isOLED) } ?? 1
        }
    }

    /// OLED by the override, else by class (the class already reflects the IORegistry minimum luminance).
    static func isOLED(facts: DisplayFacts?, override: OLEDOverride) -> Bool {
        switch override {
        case .oled: true
        case .notOLED: false
        case .automatic: facts?.panelClass == .oledExternal
        }
    }

    /// Built-in XDR and Apple XDR externals have extra brightness on by default; other HDR and OLED externals are
    /// opt-in (D8). Used only until the reducer publishes the eligibility's own default.
    static func classDefault(_ facts: DisplayFacts?) -> Bool {
        switch facts?.panelClass {
        case .builtInXDR?, .appleXDRExternal?: true
        default: false
        }
    }

    /// The display has a transfer table (or could use the overlay): dimming works.
    static func hasTable(_ facts: DisplayFacts?) -> Bool {
        guard let facts else { return true }
        return facts.gammaCapacity > 0 && facts.panelClass != .virtualDisplay
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
}
