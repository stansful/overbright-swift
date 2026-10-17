// OverbrightPanelUITests/DisplayCardModelTests.swift — what a card shows, derived from the engine's status, the facts
// and the preferences: the slider's top per cap mode and the shown presets (ARCHITECTURE.md §5.3), the boost half's
// state and the level the display shows for each (DESIGN.md §5.4, §5.5, §5.11), the allowed-now marker (§5.6,
// `GainCeiling.liveCap` lowered to the decision's binding cap, in steps of ×0.01), the chip's reason (ARCHITECTURE.md
// §6.2) and its actions (DESIGN.md §12.2), Compatibility mode for a booster's stop (§7.2).
import Foundation
import OverbrightCore
import OverbrightPolicy
import Testing
@testable import OverbrightPanelUI

@MainActor @Suite struct DisplayCardModelTests {
    private let builtIn = DisplayFixture.builtinXDRLidOpen.displays[0].facts
    private let msi = DisplayFixture.mpg322uxHDROn.displays[0].facts

    private func status(_ facts: DisplayFacts, verdict: DisplayVerdict?, phase: EnginePhase = .idle,
                        target: BoostTarget = .neutral, reasons: [LimitReason] = [], reading: HeadroomReading? = nil,
                        failedTries: Int = 0, advisories: [Advisory] = [], requested: Double = 1,
                        applied: Double = 1) -> DisplayStatus {
        let decision = verdict.map {
            DisplayDecision(key: facts.ref.key, target: target, reasons: reasons,
                            eligibility: EligibilityResult(verdict: $0, advisories: advisories, defaultBoostEnabled: true,
                                                           defaultMechanism: .table),
                            mechanism: .table, domain: .encoded, requestedGain: requested)
        }
        return DisplayStatus(key: facts.ref.key, name: facts.name, phase: phase, decision: decision, appliedGain: applied,
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

    /// The thumb, the value tag, VoiceOver, the HUD bar and the menus' checkmarks follow the level the display shows:
    /// the stored level in an active or inactive half, Standard for a boost level in a half that is switched off or
    /// unavailable (C-PANEL-1); the stored level stays what the next turn-on restores.
    @Test func theDisplayedLevelIsTheLevelTheDisplayShowsInEveryBoostHalf() {
        let brightRoom = LevelPreset.brightRoom.position
        let stored = DisplayPreferences(level: brightRoom)
        let boosting = status(builtIn, verdict: ScriptedParts.builtInVerdict, phase: .boosted, target: .boost(gain: 1.29))
        let active = model(boosting, facts: builtIn, preferences: stored)
        #expect(active.boostHalf == .active && active.displayedLevel == brightRoom)
        let inactive = model(boosting, isOn: false, facts: builtIn, preferences: stored)
        #expect(inactive.boostHalf == .inactive && inactive.displayedLevel == brightRoom)   // off: the hatch shows it
        var switchedOffPreferences = stored
        switchedOffPreferences.boostEnabled = false
        let switchedOff = model(boosting, facts: builtIn, preferences: switchedOffPreferences)
        #expect(switchedOff.boostHalf == .switchedOff && switchedOff.displayedLevel == .standard)
        #expect(switchedOff.level == brightRoom)                                            // kept for the next turn-on
        let hdrOff = model(status(msi, verdict: .turnOnHDR), facts: msi, preferences: stored)
        #expect(hdrOff.boostHalf == .unavailable(.verdict(.turnOnHDR)) && hdrOff.displayedLevel == .standard)
        let studio = DisplayFixture.studioDisplayXDR.displays[0].facts
        let safe = model(status(studio, verdict: ScriptedParts.studioVerdict), facts: studio, preferences: stored)
        #expect(safe.boostHalf == .unavailable(.safeLimitReached) && safe.displayedLevel == .standard)
        let dim = LevelMapping.position(forDimLight: 0.25)
        #expect(model(status(msi, verdict: .turnOnHDR), facts: msi, preferences: DisplayPreferences(level: dim))
            .displayedLevel == dim)                                                         // dimming still works
        let noDim = DisplayCardModel.displayed(dim, boostHalf: .active, dimEnabled: false)
        #expect(noDim == .standard)
    }

    /// The menus check Standard for a display whose extra brightness is off at a boost level, never nothing.
    @Test func theMenusCheckTheDisplayedLevel() {
        var preferences = DisplayPreferences(level: LevelPreset.brightRoom.position)
        preferences.boostEnabled = false
        let card = model(status(builtIn, verdict: ScriptedParts.builtInVerdict), facts: builtIn, preferences: preferences)
        let items = CardMenu.items(for: card, lastDimLight: 0.25, contextMenu: false)
        #expect(items.first == .level(.standard, isChecked: true))
        #expect(items.filter(CardMenu.isChecked).count == 1)
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
        #expect(peak.allowedNow == 1.55)                                 // "macOS allows ×1.55 now" (×0.01 steps)
        let safe = model(boosting, facts: builtIn)
        #expect(abs((safe.allowedNow ?? 0) - 1.0) < 0.001)              // the live Safe bound: 1000 × 1.6 ÷ 1600
        #expect(model(boosting, isOn: false, facts: builtIn).allowedNow == nil)
        let idle = status(builtIn, verdict: ScriptedParts.builtInVerdict, reading: outdoors)
        #expect(model(idle, facts: builtIn).allowedNow == nil)          // never armed: no marker
        #expect(model(boosting, facts: nil).allowedNow == nil)
    }

    /// The marker stops where the readout says the display is limited, whatever binds (C-PANEL-6): heat and Safe with a
    /// trusted SDR white lower the decision's own gain; macOS's limit and "near full brightness" show in the gain on
    /// screen once steady; a limit that does not bind moves nothing.
    @Test func theMarkerStopsAtTheCapThatBinds() {
        let reading = ScriptedParts.reading(builtIn, current: 2.667, potential: 16)        // full range: no live cap
        let peak = DisplayPreferences(capMode: .peak)
        func marker(_ reasons: [LimitReason], target: Double, applied: Double, requested: Double = 1.6,
                    phase: EnginePhase = .boosted) -> Double? {
            model(status(builtIn, verdict: ScriptedParts.builtInVerdict, phase: phase, target: .boost(gain: target),
                         reasons: reasons, reading: reading, requested: requested, applied: applied),
                  facts: builtIn, preferences: peak).allowedNow
        }
        let open = marker([], target: 1.6, applied: 1.6)
        #expect(abs((open ?? 0) - 0.97 * 1600 / 600) < 0.001)                               // the top, nothing binds
        #expect(marker([.thermalSerious], target: 1.2, applied: 1.2) == 1.2)               // heat: the reducer's ×1.2
        #expect(marker([.thermalSerious], target: 1.2, applied: 1.05, phase: .ramping) == 1.2)
        #expect(marker([.safeLimit], target: 1.33, applied: 1.33) == 1.33)                 // Safe, trusted SDR white
        #expect(marker([.oledLimit], target: 1.3, applied: 1.3) == 1.3)
        #expect(marker([.headroom], target: 1.6, applied: 1.42) == 1.42)                   // macOS's limit, steady
        #expect(marker([.nearFullBrightnessOnly], target: 1.6, applied: 1.12) == 1.12)     // the taper, steady
        #expect(marker([.headroom], target: 1.6, applied: 1.3, phase: .ramping) == open)   // not steady yet
        #expect(marker([.fullScreenVideo], target: 1.6, applied: 1.2) == open)             // not a cap
        #expect(marker([.headroom], target: 1.6, applied: 1.6) == open)                    // a cap that does not bind
    }

    /// The marker moves in steps of ×0.01, the figure its help tag states, and never above the top (C-PANEL-29).
    @Test func theMarkerMovesOnlyWhenItsFigureDoes() {
        #expect(DisplayCardModel.quantized(1.5523, top: 2.587) == 1.55)
        #expect(DisplayCardModel.quantized(1.5549, top: 2.587) == 1.55)
        #expect(DisplayCardModel.quantized(1.5551, top: 2.587) == 1.56)
        #expect(DisplayCardModel.quantized(1.667, top: 1.6667) == 1.6667)
        let readings = [1.6, 1.601, 1.602, 1.603].map { ScriptedParts.reading(builtIn, current: $0, potential: 16) }
        let markers = Set(readings.map { reading in
            model(status(builtIn, verdict: ScriptedParts.builtInVerdict, phase: .boosted, target: .boost(gain: 1.55),
                         reading: reading), facts: builtIn, preferences: DisplayPreferences(capMode: .peak)).allowedNow
        })
        #expect(markers.count == 1)                                                         // polls that move by less
    }

    // MARK: OLED notice

    /// A move into the boost half of an OLED display whose notice is unanswered waits at Standard; moving back to
    /// Standard or below drops it, so releasing there asks nothing, and the notice sets the level released at
    /// (C-PANEL-26).
    @Test func theOLEDNoticeAsksOnlyForABoostLevelAndForTheOneReleased() {
        var gate = OLEDBoostGate()
        #expect(gate.move(to: LevelPosition(0.5), waitsForNotice: true) == .standard)
        #expect(gate.move(to: LevelPosition(0.7), waitsForNotice: true) == .standard)
        #expect(gate.pending == LevelPosition(0.7))
        #expect(gate.release() == LevelPosition(0.7))                       // released in the boost half: asked
        #expect(gate.release() == nil)
        _ = gate.move(to: LevelPosition(0.5), waitsForNotice: true)
        #expect(gate.move(to: LevelPosition(-0.2), waitsForNotice: false) == LevelPosition(-0.2))
        #expect(gate.release() == nil)                                      // released below Standard: nothing asked
        _ = gate.move(to: LevelPosition(0.5), waitsForNotice: true)
        #expect(gate.move(to: .standard, waitsForNotice: true) == .standard)
        #expect(gate.release() == nil)                                      // back at Standard: nothing asked
        #expect(gate.move(to: LevelPosition(0.4), waitsForNotice: false) == LevelPosition(0.4))   // no notice needed
        #expect(gate.release() == nil)
    }

    /// The notice names the configured idle pause, as Settings' notice does, in the locale's words (C-PANEL-20).
    @Test func theOLEDNoticeNamesTheConfiguredIdleTime() {
        let english = Locale(identifier: "en_US")
        #expect(OLEDNotice.idleDuration(minutes: 10, locale: english) == "10 minutes")
        #expect(OLEDNotice.idleDuration(minutes: 60, locale: english) == "1 hour")
        #expect(OLEDNotice.message(idleMinutes: 10, locale: english) != OLEDNotice.message(idleMinutes: 5, locale: english))
        #expect(OLEDNotice.message(idleMinutes: 15, locale: english).contains(OLEDNotice.idleDuration(minutes: 15,
                                                                                                     locale: english)))
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
        let booster = ConflictingApp(entryID: "b", severity: .booster, bundleID: nil, processID: 1, displayName: "B")
        let colorApp = ConflictingApp(entryID: "c", severity: .gammaWriter, bundleID: nil, processID: 2, displayName: "C")
        #expect(kinds([.tripped(.attributedDrift(booster))]) == [.continueInCompatibilityMode(booster)])   // not Continue
        #expect(CardAction.continueInCompatibilityMode(booster).title == CardAction.useCompatibilityMode.title)
        #expect(kinds([.tripped(.attributedDrift(colorApp))]) == [.continueAnyway(colorApp)])
        #expect(kinds([.headroom]).isEmpty)
        #expect(kinds([.thermalSerious]).isEmpty)
    }
}
