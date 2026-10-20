// OverbrightPanelUI/QA/ScriptedParts.swift — the pieces the scripted statuses are made of: fixture displays, readings,
// verdicts, decisions and statuses with the numbers of ARCHITECTURE.md §5.3 and §5.6 (computed, not measured).
// Synthetic display keys use the fixtures' 0B21E7F1 prefix; app names are invented, bundle IDs synthetic (D3).
import Foundation
import OverbrightCore
import OverbrightPolicy

/// Building blocks of `ScriptedStatuses`.
enum ScriptedParts {
    /// The fixed wall clock of every scripted state (ManualTimeSource's default start).
    static let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    // MARK: Displays

    /// The M4 Max built-in (P3-1600, SDR max 600, notch).
    static let builtIn = DisplayFixture.builtinXDRLidOpen.displays[0].facts
    /// The MSI MPG322UX OLED with macOS HDR on.
    static let msi = DisplayFixture.mpg322uxHDROn.displays[0].facts
    /// The MSI with HDR off.
    static let msiHDROff = DisplayFixture.mpg322uxHDROff.displays[0].facts
    /// A MacBook Air-class LCD built-in.
    static let lcd = DisplayFixture.lcdOnly.displays[0].facts
    /// A Sidecar display.
    static let sidecar = DisplayFixture.sidecar.displays[1].facts
    /// The Pro Display XDR.
    static let proDisplay = DisplayFixture.proDisplayXDR.displays[0].facts
    /// The Studio Display XDR.
    static let studioDisplay = DisplayFixture.studioDisplayXDR.displays[0].facts
    /// A second MSI with the same name.
    static let msiTwin: DisplayFacts = {
        var facts = msi
        facts.ref = DisplayRef(key: DisplayKey(rawValue: "0B21E7F1-0000-4000-8000-0000000000A2"), id: 12)
        return facts
    }()
    /// An HDR external (not OLED, not Apple): 700-nit peak, SDR white 300 in HDR mode (Safe ×1.40, Peak ×2.26).
    static let hdrExternal = DisplayFacts(ref: DisplayRef(key: DisplayKey(rawValue: "0B21E7F1-0000-4000-8000-0000000000A1"),
                                                          id: 11),
                                          name: "HDR Monitor 27", isBuiltIn: false, gammaCapacity: 1024,
                                          supportsPQ: true, panelPeakNits: 700, panelFrameAverageNits: 300,
                                          panelMinNits: 0.05, sdrMaxNits: 300, panelClass: .hdrExternal)
    /// The built-in with a long Russian name.
    static let builtInRussian: DisplayFacts = {
        var facts = builtIn
        facts.name = "Встроенный дисплей Liquid Retina XDR (основной)"
        return facts
    }()

    // MARK: Verdicts (the slider tops at full brightness, ARCHITECTURE.md §5.3)

    /// M4 Max built-in: Safe ×1.667, Peak ×2.587.
    static let builtInVerdict = DisplayVerdict.supported(safeGain: 1000.0 / 600, peakGain: 0.97 * 1600 / 600)
    /// MSI OLED: Safe ×1.3, Peak ×1.704.
    static let msiVerdict = DisplayVerdict.supported(safeGain: 1.3, peakGain: 0.97 * 465.49 / 265.05)
    /// The HDR external: Safe ×1.40, Peak ×2.263.
    static let hdrExternalVerdict = DisplayVerdict.supported(safeGain: 420.0 / 300, peakGain: 0.97 * 700 / 300)
    /// Pro Display XDR: Safe ×2.0, Peak ×3.104.
    static let proVerdict = DisplayVerdict.supported(safeGain: 2, peakGain: 0.97 * 1600 / 500)
    /// Studio Display XDR: no Safe boost, Peak ×1.94.
    static let studioVerdict = DisplayVerdict.supported(safeGain: nil, peakGain: 0.97 * 2000 / 1000)

    /// An eligibility result.
    static func eligibility(_ verdict: DisplayVerdict, advisories: [Advisory] = [], boostByDefault: Bool = true)
        -> EligibilityResult {
        EligibilityResult(verdict: verdict, advisories: advisories, defaultBoostEnabled: boostByDefault)
    }

    // MARK: Statuses

    /// A reading of `facts` now.
    static func reading(_ facts: DisplayFacts, current: Double, potential: Double) -> HeadroomReading {
        HeadroomReading(display: facts.ref.id, current: current, potential: potential, reference: 0,
                        time: MonotonicInstant(sinceOrigin: .seconds(100)))
    }

    /// One display's status: `gain` is the light gain on screen (1 = Standard).
    static func display(_ facts: DisplayFacts, phase: EnginePhase = .idle, target: BoostTarget = .neutral,
                        reasons: [LimitReason] = [], eligibility: EligibilityResult, gain: Double = 1, requested: Double? = nil, reading: HeadroomReading? = nil,
                        sdrWhite: SDRWhiteEstimate? = nil, failedTries: Int = 0) -> DisplayStatus {
        let decision = DisplayDecision(key: facts.ref.key, target: target, reasons: reasons, eligibility: eligibility,
                                       domain: .encoded, requestedGain: requested ?? gain)
        return DisplayStatus(key: facts.ref.key, name: facts.name, phase: phase, decision: decision, appliedGain: gain,
                             appliedFactor: FactorMath.tableFactor(forLightGain: gain, domain: .encoded),
                             strategy: phase == .idle ? nil : .taggedLayer, lastReading: reading,
                             sdrWhite: sdrWhite, failedTries: failedTries)
    }

    /// The built-in boosted at `gain` (macOS granting `headroom`).
    static func builtInBoosted(_ gain: Double, headroom: Double = 1600.0 / 600, reasons: [LimitReason] = [],
                               advisories: [Advisory] = [.notCalibrated], requested: Double? = nil,
                               facts: DisplayFacts = builtIn) -> DisplayStatus {
        display(facts, phase: .boosted, target: .boost(gain: requested ?? gain), reasons: reasons,
                eligibility: eligibility(builtInVerdict, advisories: advisories), gain: gain, requested: requested,
                reading: reading(facts, current: headroom, potential: 16))
    }

    /// The MSI idle at Standard (extra brightness opt-in, off by default).
    static func msiStandard(reasons: [LimitReason] = []) -> DisplayStatus {
        display(msi, reasons: reasons, eligibility: eligibility(msiVerdict, advisories: [.oledCare, .notCalibrated],
                                                                boostByDefault: false))
    }

    /// The MSI boosted at `gain`.
    static func msiBoosted(_ gain: Double, reasons: [LimitReason] = [], sdrWhite: SDRWhiteEstimate? = nil,
                           advisories: [Advisory] = [.oledCare, .notCalibrated]) -> DisplayStatus {
        display(msi, phase: .boosted, target: .boost(gain: gain), reasons: reasons,
                eligibility: eligibility(msiVerdict, advisories: advisories, boostByDefault: false), gain: gain,
                reading: reading(msi, current: 465.49 / 265.05, potential: 4.6549), sdrWhite: sdrWhite)
    }

    /// Every display stopped by `reason` (a global stop or guard): neutral, the reason first.
    static func held(_ statuses: [DisplayStatus], by reason: LimitReason) -> [DisplayStatus] {
        statuses.map { status in
            var status = status
            status.phase = .idle
            status.appliedGain = 1
            status.appliedFactor = 1
            if var decision = status.decision {
                decision.target = .neutral
                decision.reasons = [reason] + decision.reasons
                status.decision = decision
            }
            return status
        }
    }

    /// A status of `displays`.
    static func status(_ displays: [DisplayStatus], isOn: Bool = true, symbol: StatusSymbolState? = nil,
                       banner: Banner? = nil, pausedUntil: Date? = nil, autoOffAt: Date? = nil,
                       lastChange: LevelChange? = nil, pendingLowLevel: LowLevelConfirmation? = nil) -> BoostStatus {
        BoostStatus(isOn: isOn, isReady: true, pausedUntil: pausedUntil, autoOffAt: autoOffAt, displays: displays,
                    banner: banner, symbol: symbol ?? (isOn ? .on : .off), lastChange: lastChange,
                    pendingLowLevel: pendingLowLevel)
    }

    /// A level change for the HUD gallery.
    static func change(_ kind: LevelChange.Kind, source: ControlSource = .shortcut, display: DisplayKey? = nil)
        -> LevelChange {
        LevelChange(sequence: 1, kind: kind, source: source, display: display)
    }

    /// A conflicting app with an invented name and a synthetic bundle ID.
    static func app(_ name: String, severity: ConflictSeverity) -> ConflictingApp {
        ConflictingApp(entryID: "example.\(severity.rawValue)", severity: severity,
                       bundleID: "com.example.\(severity.rawValue)", processID: 4242, displayName: name)
    }

    /// The level of the built-in "Dimmed · 25 %".
    static let dimmed25 = LevelMapping.position(forDimLight: 0.25)
}
