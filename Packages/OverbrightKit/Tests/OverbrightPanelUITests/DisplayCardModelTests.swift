// OverbrightPanelUITests/DisplayCardModelTests.swift — what a card shows, derived from the engine's status, the facts
// and the preferences: the slider's top per cap mode and the shown presets (ARCHITECTURE.md §5.3), the boost half's
// state (DESIGN.md §5.4, §5.5, §5.11), the allowed-now marker (§5.6, `GainCeiling.liveCap`), the chip's reason
// (ARCHITECTURE.md §6.2) and its actions (DESIGN.md §12.2).
import OverbrightCore
import OverbrightPolicy
import Testing
@testable import OverbrightPanelUI

@MainActor @Suite struct DisplayCardModelTests {
    private let builtIn = DisplayFixture.builtinXDRLidOpen.displays[0].facts
    private let msi = DisplayFixture.mpg322uxHDROn.displays[0].facts

    private func status(_ facts: DisplayFacts, verdict: DisplayVerdict?, phase: EnginePhase = .idle,
                        target: BoostTarget = .neutral, reasons: [LimitReason] = [], reading: HeadroomReading? = nil,
                        failedTries: Int = 0, advisories: [Advisory] = []) -> DisplayStatus {
        let decision = verdict.map {
            DisplayDecision(key: facts.ref.key, target: target, reasons: reasons,
                            eligibility: EligibilityResult(verdict: $0, advisories: advisories, defaultBoostEnabled: true,
                                                           defaultMechanism: .table),
                            mechanism: .table, domain: .encoded, requestedGain: 1)
        }
        return DisplayStatus(key: facts.ref.key, name: facts.name, phase: phase, decision: decision, appliedGain: 1,
                             appliedFactor: 1, mechanism: .table, strategy: nil, lastReading: reading, sdrWhite: nil,
                             failedTries: failedTries)
    }

    private func model(_ status: DisplayStatus, isOn: Bool = true, paused: Bool = false, banner: Banner? = nil,
                       facts: DisplayFacts? = nil, preferences: DisplayPreferences = DisplayPreferences(),
                       linked: LevelPosition? = nil) -> DisplayCardModel {
        DisplayCardModel(status: status, isMasterOn: isOn, isPaused: paused, banner: banner, facts: facts,
                         preferences: preferences, linkLevels: linked != nil, linkedLevel: linked ?? .standard, taper: true)
    }

    // MARK: Top and presets

    @Test func theTopFollowsTheCapModeAndThePresetsFollowTheTop() {
        let supported = status(builtIn, verdict: ScriptedParts.builtInVerdict)
        let safe = model(supported, facts: builtIn)
        #expect(abs(safe.top - 1.667) < 0.001)
        #expect(safe.presets == [.indoor, .brightRoom, .sunlight, .max])
        let peak = model(supported, facts: builtIn, preferences: DisplayPreferences(capMode: .peak))
        #expect(abs(peak.top - 2.587) < 0.001)
        #expect(abs(peak.peakTop - 2.587) < 0.001)
        let oled = model(status(msi, verdict: ScriptedParts.msiVerdict), facts: msi,
                         preferences: DisplayPreferences(boostEnabled: true))
        #expect(oled.presets == [.brightRoom, .max])                    // ARCHITECTURE.md §5.3: Indoor < ×1.1
        #expect(oled.isOLED && oled.hasSmallGain)
        #expect(!safe.hasSmallGain)
    }

    @Test func aSafeTopBelowTheMinimumDisablesTheBoostHalfWithTheRightReason() {
        let studio = DisplayFixture.studioDisplayXDR.displays[0].facts
        let card = model(status(studio, verdict: ScriptedParts.studioVerdict), facts: studio)
        #expect(card.boostHalf == .unavailable(.safeLimitReached))       // Safe adds nothing; Peak would
        #expect(!card.canBoost)
        let little = model(status(builtIn, verdict: .noGainAtFullBrightness(peakGain: 1.03)), facts: builtIn)
        #expect(little.boostHalf == .unavailable(.littleGain))
        let hdrOff = model(status(msi, verdict: .turnOnHDR), facts: msi)
        #expect(hdrOff.boostHalf == .unavailable(.verdict(.turnOnHDR)))
        #expect(hdrOff.dimEnabled)                                      // dimming still works
    }

    // MARK: Boost half

    @Test func theBoostHalfIsWarmOnlyWhileExtraLightIsOnScreen() {
        let boosting = status(builtIn, verdict: ScriptedParts.builtInVerdict, phase: .boosted,
                              target: .boost(gain: 1.29))
        #expect(model(boosting, facts: builtIn).boostHalf == .active)
        #expect(model(boosting, isOn: false, facts: builtIn).boostHalf == .inactive)
        #expect(model(boosting, paused: true, facts: builtIn).boostHalf == .inactive)
        let guarded = status(builtIn, verdict: ScriptedParts.builtInVerdict, reasons: [.lowPowerMode])
        #expect(model(guarded, facts: builtIn).boostHalf == .inactive)  // a guard holds a boost level at Standard
        let switchedOff = model(boosting, facts: builtIn, preferences: DisplayPreferences(boostEnabled: false))
        #expect(switchedOff.boostHalf == .switchedOff)
    }

    @Test func linkedLevelsReplaceTheDisplaysOwnLevel() {
        let card = model(status(builtIn, verdict: ScriptedParts.builtInVerdict), facts: builtIn,
                         preferences: DisplayPreferences(level: LevelPosition(0.25)), linked: LevelPosition(0.75))
        #expect(card.isLinked && card.level == LevelPosition(0.75))
        let own = model(status(builtIn, verdict: ScriptedParts.builtInVerdict), facts: builtIn,
                        preferences: DisplayPreferences(level: LevelPosition(0.25)))
        #expect(!own.isLinked && own.level == LevelPosition(0.25))
    }

    // MARK: Marker

    @Test func theMarkerIsTheLiveCapOfTheTopWhileBoostingAndHiddenOtherwise() {
        let outdoors = ScriptedParts.reading(builtIn, current: 1.6, potential: 16)
        let boosting = status(builtIn, verdict: ScriptedParts.builtInVerdict, phase: .boosted,
                              target: .boost(gain: 1.55), reading: outdoors)
        let peak = model(boosting, facts: builtIn, preferences: DisplayPreferences(capMode: .peak))
        #expect(abs((peak.allowedNow ?? 0) - 0.97 * 1.6) < 0.001)      // "macOS allows ×1.55 now"
        let safe = model(boosting, facts: builtIn)
        #expect(abs((safe.allowedNow ?? 0) - 1.0) < 0.001)              // the live Safe bound: 1000 × 1.6 ÷ 1600
        #expect(model(boosting, isOn: false, facts: builtIn).allowedNow == nil)
        let idle = status(builtIn, verdict: ScriptedParts.builtInVerdict, reading: outdoors)
        #expect(model(idle, facts: builtIn).allowedNow == nil)          // never armed: no marker
        #expect(model(boosting, facts: nil).allowedNow == nil)
    }

    // MARK: Chip

    @Test func theChipShowsTheFirstPerDisplayReasonOnly() {
        let key = builtIn.ref.key
        let reasons: [LimitReason] = [.lowPowerMode, .safeLimit, .headroom]
        let decision = status(builtIn, verdict: ScriptedParts.builtInVerdict, reasons: reasons).decision
        #expect(CardChip.reason(decision: decision, key: key, banner: .lowPowerMode, isMasterOn: true) == .safeLimit)
        #expect(CardChip.reason(decision: decision, key: key, banner: nil, isMasterOn: false) == nil)
        let off = status(builtIn, verdict: ScriptedParts.builtInVerdict, reasons: [.masterOff]).decision
        #expect(CardChip.reason(decision: off, key: key, banner: nil, isMasterOn: true) == nil)
        let s3 = ConflictingApp(entryID: "x", severity: .conditional, bundleID: nil, processID: 1, displayName: "A")
        let s1 = ConflictingApp(entryID: "y", severity: .booster, bundleID: nil, processID: 2, displayName: "B")
        let conflicts = status(builtIn, verdict: ScriptedParts.builtInVerdict, reasons: [.conflict(s1), .conflict(s3)]).decision
        #expect(CardChip.reason(decision: conflicts, key: key, banner: .conflict(s1), isMasterOn: true) == .conflict(s3))
    }

    @Test func aTripTheBannerNamesIsNotRepeatedOnTheCard() {
        let key = builtIn.ref.key
        let other = msi.ref.key
        let decision = status(builtIn, verdict: ScriptedParts.builtInVerdict, reasons: [.tripped(.oscillation)]).decision
        #expect(CardChip.reason(decision: decision, key: key, banner: .flickerStop(display: key), isMasterOn: true) == nil)
        #expect(CardChip.reason(decision: decision, key: key, banner: .flickerStop(display: other), isMasterOn: true)
            == .tripped(.oscillation))
    }

    @Test func aDimOnlyDisplayShowsItsVerdict() {
        let decision = status(msi, verdict: .turnOnHDR).decision
        #expect(CardChip.reason(decision: decision, key: msi.ref.key, banner: nil, isMasterOn: true)
            == .notSupported(.turnOnHDR))
        let virtual = status(msi, verdict: .virtualDisplay).decision
        #expect(CardChip.reason(decision: virtual, key: msi.ref.key, banner: nil, isMasterOn: true) == nil)
    }

    @Test func chipActionsFollowTheCopyCatalogue() {
        func kinds(_ reasons: [LimitReason], phase: EnginePhase = .idle, tries: Int = 0,
                   advisories: [Advisory] = []) -> [CardAction] {
            let card = model(status(builtIn, verdict: ScriptedParts.builtInVerdict, phase: phase, reasons: reasons,
                                    failedTries: tries, advisories: advisories), facts: builtIn)
            return CardChip.kinds(for: card, isMasterOn: true)
        }
        let anchor = HelpEntry.Anchor.noExtraRange
        #expect(kinds([], phase: .failed(.headroomNeverArrived), tries: 1) == [.tryAgain, .learnMore(anchor)])
        #expect(kinds([], phase: .failed(.headroomNeverArrived), tries: 2) == [.tryAgain, .runSelfTest, .learnMore(anchor)])
        #expect(kinds([], phase: .failed(.headroomNeverArrived), tries: 2, advisories: [.compatibilityModeAdvised])
            == [.tryAgain, .runSelfTest, .useCompatibilityMode, .learnMore(anchor)])
        #expect(kinds([.boostNotEnabled]) == [.turnOnExtraBrightness])
        #expect(kinds([.safeLimit]) == [.choosePeak])
        #expect(kinds([.oledLimit]) == [.choosePeak])
        #expect(kinds([.nearFullBrightnessOnly]) == [.changeTaperSetting])
        #expect(kinds([.fullScreenVideo]) == [.changeRules])
        #expect(kinds([.pausedApp(bundleID: "com.example.player")]) == [.editApps])
        #expect(kinds([.tripped(.oscillation)]) == [.tryAgain])
        #expect(kinds([.tripped(.foreignTableAtLaunch)]) == [.openDisplaySettings])
        #expect(kinds([.headroom]).isEmpty)
        #expect(kinds([.thermalSerious]).isEmpty)
    }
}
