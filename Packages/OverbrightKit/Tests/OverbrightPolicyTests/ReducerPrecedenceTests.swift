// OverbrightPolicyTests/ReducerPrecedenceTests.swift — every row of the precedence table of ARCHITECTURE.md §6.1, the
// boost-only rule (dimming passes), step 7's caps (§5.4) and the conflict continuation rules of §7.2.
import Foundation
import OverbrightCore
import OverbrightTestSupport
import Testing
@testable import OverbrightPolicy

@Suite struct ReducerPrecedenceTests {
    private typealias T = PolicyTestInputs
    private let max = LevelPreset.max.position
    private let brightRoom = LevelPreset.brightRoom.position
    private let dimHalf = LevelPosition(-0.5)
    private let builtInKey = DisplayFixture.Keys.builtIn

    private func decide(_ displays: [DisplayPolicyInput] = [T.display()], master: Bool = true,
                        settings: PolicySettings = PolicySettings(), system: SystemSnapshot = T.system(),
                        pausedUntil: Date? = nil, minuteOfDay: Int = 600, continued: Set<String> = [],
                        machine: MachineIdentity = DisplayFixture.ownerMachine) -> PolicyDecision {
        BoostPolicy.reduce(T.input(displays, master: master, settings: settings, system: system, pausedUntil: pausedUntil,
                                   minuteOfDay: minuteOfDay, machine: machine, continued: continued))
    }
    private func builtIn(_ level: LevelPosition, settings: PolicySettings = PolicySettings(),
                         system: SystemSnapshot = T.system(), pausedUntil: Date? = nil, minuteOfDay: Int = 600,
                         continued: Set<String> = [], trip: TripCause? = nil, capMode: CapMode = .safe,
                         mechanism: MechanismPreference = .automatic, boostEnabled: Bool? = nil) -> DisplayDecision? {
        decide([T.display(level: level, boostEnabled: boostEnabled, capMode: capMode, mechanism: mechanism, trip: trip)],
               settings: settings, system: system, pausedUntil: pausedUntil, minuteOfDay: minuteOfDay,
               continued: continued).builtIn
    }
    /// Stops the boost and the dim half with `reason` first.
    private func stopsBothHalves(_ reason: LimitReason, settings: PolicySettings = PolicySettings(),
                                 system: SystemSnapshot = T.system(), pausedUntil: Date? = nil,
                                 trip: TripCause? = nil) -> Bool {
        [brightRoom, dimHalf].allSatisfy { level in
            let decision = builtIn(level, settings: settings, system: system, pausedUntil: pausedUntil, trip: trip)
            return decision?.target == .neutral && decision?.reasons.first == reason
        }
    }
    /// Stops the boost half with `reason` first, and lets the dim half through.
    private func stopsOnlyTheBoostHalf(_ reason: LimitReason, settings: PolicySettings = PolicySettings(),
                                       system: SystemSnapshot = T.system(), minuteOfDay: Int = 600,
                                       boostEnabled: Bool? = nil) -> Bool {
        let boost = builtIn(brightRoom, settings: settings, system: system, minuteOfDay: minuteOfDay,
                            boostEnabled: boostEnabled)
        let dim = builtIn(dimHalf, settings: settings, system: system, minuteOfDay: minuteOfDay,
                          boostEnabled: boostEnabled)
        return boost?.target == .neutral && boost?.reasons == [reason] && dim?.dimLight != nil && dim?.reasons == []
    }
    private func boosts(settings: PolicySettings = PolicySettings(), system: SystemSnapshot = T.system(),
                        minuteOfDay: Int = 600) -> Bool {
        builtIn(brightRoom, settings: settings, system: system, minuteOfDay: minuteOfDay)?.boostGain != nil
    }

    @Test func theUnlimitedBaseline() throws {
        let decision = try #require(builtIn(brightRoom))
        #expect(abs((decision.boostGain ?? 0) - 1.291) < 0.0005 && decision.reasons.isEmpty)
        #expect(abs(decision.requestedGain - 1.291) < 0.0005 && decision.level == brightRoom)
        #expect(decision.mechanism == .table && decision.domain == .encoded)
        #expect(builtIn(.standard)?.target == .neutral && builtIn(.standard)?.reasons == [])
        #expect(abs((builtIn(dimHalf)?.dimLight ?? 0) - 0.501) < 0.0005)
    }

    @Test func row1MasterOff() {
        for level in [brightRoom, dimHalf, .standard] {
            let decision = decide([T.display(level: level)], master: false).builtIn
            #expect(decision?.target == .neutral && decision?.reasons == [.masterOff])
        }
    }

    @Test func row2TheVerdictForbidsTheRequestedHalf() {
        let hdrOff = DisplayFixture.mpg322uxHDROff.displays[0]
        let off = decide([T.display(hdrOff, level: brightRoom, boostEnabled: true)]).displays[DisplayFixture.Keys.mpg322ux]
        #expect(off?.target == .neutral && off?.reasons.first == .notSupported(.turnOnHDR))
        #expect(decide([T.display(hdrOff, level: dimHalf)]).displays[DisplayFixture.Keys.mpg322ux]?.dimLight != nil)
        let projector = { (level: LevelPosition) in
            self.decide([T.display(T.projector, level: level)]).displays[DisplayFixture.Keys.projector]
        }
        #expect(projector(brightRoom)?.reasons.first == .notSupported(.mirrored))
        #expect(projector(dimHalf)?.dimLight != nil)                                       // mirrors: dim only
        let sidecar = DisplayFixture.sidecar.displays[1]
        #expect(decide([T.display(sidecar, level: dimHalf)]).displays[DisplayFixture.Keys.sidecar]?.reasons.first
                == .notSupported(.virtualDisplay))
        let unread = decide([T.display(level: dimHalf, reading: .some(nil))]).builtIn
        #expect(unread?.target == .neutral && unread?.reasons.first == .notSupported(.checking))
        // Standard asks for neither half: no reason even where nothing works.
        #expect(decide([T.display(sidecar, level: .standard)]).displays[DisplayFixture.Keys.sidecar]?.reasons == [])
    }

    @Test func row3Shielded() {
        let power = T.adapter
        for snapshot in [SystemSnapshot(power: power, isScreenLocked: true),
                         SystemSnapshot(power: power, isScreensaverRunning: true),
                         SystemSnapshot(power: power, areDisplaysAsleep: true),
                         SystemSnapshot(power: power, isSystemSleeping: true),
                         SystemSnapshot(power: power, isSessionActive: false)] {
            #expect(stopsBothHalves(.shielded, system: snapshot))
        }
    }

    @Test func row4Conflicts() {
        func system(_ apps: ConflictingApp...) -> SystemSnapshot { SystemSnapshot(power: T.adapter, conflicts: apps) }
        let booster = T.app(.booster, entry: "booster-x")
        let colors = T.app(.gammaWriter, entry: "gamma-x")
        #expect(stopsBothHalves(.conflict(booster), system: system(booster)))
        #expect(stopsBothHalves(.conflict(colors), system: system(colors)))
        #expect(stopsBothHalves(.conflict(booster), system: system(colors, booster)))       // S1 before S2
        // S1 continues only on an overlay display, which no display uses while Compatibility mode is unavailable
        // (§7.5: a stored overlay preference uses the table), and never through "always continue".
        #expect(builtIn(brightRoom, system: system(booster), continued: ["booster-x"])?.target == .neutral)
        #expect(builtIn(brightRoom, system: system(booster), continued: ["booster-x"], mechanism: .overlay)?.target
                == .neutral)
        #expect(builtIn(brightRoom, settings: PolicySettings(alwaysContinueEntryIDs: ["booster-x"]), system: system(booster),
                        mechanism: .overlay)?.target == .neutral)
        // S2 continues for this session or always.
        #expect(builtIn(brightRoom, system: system(colors), continued: ["gamma-x"])?.boostGain != nil)
        #expect(builtIn(brightRoom, settings: PolicySettings(alwaysContinueEntryIDs: ["gamma-x"]),
                        system: system(colors))?.boostGain != nil)
        // S3: a non-blocking reason after the caps, dropped once continued; S4: nothing.
        let conditional = T.app(.conditional, entry: "conditional-x")
        let s3 = builtIn(max, system: system(conditional))
        #expect(s3?.boostGain != nil && s3?.reasons == [.safeLimit, .conflict(conditional)])
        #expect(builtIn(dimHalf, system: system(conditional))?.reasons == [.conflict(conditional)])
        #expect(builtIn(brightRoom, system: system(conditional), continued: ["conditional-x"])?.reasons == [])
        #expect(builtIn(brightRoom, system: system(T.app(.benign)))?.reasons == [])
    }

    @Test func row5EngineTrips() {
        let app = T.app(.conditional)
        for trip in [TripCause.oscillation, .repairBudgetExceeded, .attributedDrift(app), .headroomNeverArrived,
                     .foreignTableAtLaunch] {
            #expect(stopsBothHalves(.tripped(trip), trip: trip))
        }
        // Per display: the other display keeps boosting.
        let other = T.display(DisplayFixture.proDisplayXDR.displays[0])
        let decision = decide([T.display(trip: .oscillation), other])
        #expect(decision.builtIn?.target == .neutral)
        #expect(decision.displays[DisplayFixture.Keys.proDisplayXDR]?.boostGain != nil)
    }

    @Test func row6UserPause() {
        let until = T.now.addingTimeInterval(3600)
        #expect(stopsBothHalves(.userPaused(until: until), pausedUntil: until))
        #expect(builtIn(brightRoom, pausedUntil: T.now)?.boostGain != nil)                   // ended at `now`
        #expect(builtIn(brightRoom, pausedUntil: T.now.addingTimeInterval(-60))?.boostGain != nil)
    }

    @Test func row7FocusOff() {
        #expect(stopsBothHalves(.focusOff, system: SystemSnapshot(power: T.adapter, focus: .off)))
        #expect(boosts(system: SystemSnapshot(power: T.adapter, focus: .leaveAlone)))
    }

    @Test func row8ThePerDisplayBoostSwitch() {
        #expect(stopsOnlyTheBoostHalf(.boostNotEnabled, boostEnabled: false))
        // The class default: an OLED external is opt-in, the built-in XDR is on.
        let msi = decide([T.display(T.msi)]).displays[DisplayFixture.Keys.mpg322ux]
        #expect(msi?.target == .neutral && msi?.reasons == [.boostNotEnabled])
        #expect(decide([T.display(T.msi, boostEnabled: true)]).displays[DisplayFixture.Keys.mpg322ux]?.boostGain != nil)
    }

    @Test func row9ThermalCritical() {
        #expect(stopsOnlyTheBoostHalf(.thermalCritical, system: SystemSnapshot(power: T.adapter, thermal: .critical)))
        #expect(boosts(system: SystemSnapshot(power: T.adapter, thermal: .fair)))
    }

    @Test func row10LowPowerMode() {
        let lowPower = SystemSnapshot(power: PowerState(source: .adapter, batteryPercent: 90, isLowPowerMode: true))
        #expect(stopsOnlyTheBoostHalf(.lowPowerMode, system: lowPower))
        #expect(boosts(settings: PolicySettings(pauseInLowPowerMode: false), system: lowPower))
    }

    @Test func row11OnBatteryWithAdapterOnly() {
        let battery = SystemSnapshot(power: PowerState(source: .battery, batteryPercent: 90, isLowPowerMode: false))
        #expect(stopsOnlyTheBoostHalf(.onBattery, settings: PolicySettings(batteryGuard: .onlyOnAdapter), system: battery))
        #expect(boosts(settings: PolicySettings(batteryGuard: .onlyOnAdapter)))
        #expect(boosts(settings: PolicySettings(batteryGuard: .off), system: battery))
    }

    @Test func row12BatteryBelowTheThreshold() {
        func on(_ percent: Int?) -> SystemSnapshot {
            SystemSnapshot(power: PowerState(source: .battery, batteryPercent: percent, isLowPowerMode: false))
        }
        #expect(stopsOnlyTheBoostHalf(.battery(percent: 15, threshold: 20), system: on(15)))
        #expect(boosts(system: on(20)) && boosts(system: on(nil)))
        #expect(stopsOnlyTheBoostHalf(.battery(percent: 45, threshold: 50),
                                      settings: PolicySettings(batteryThreshold: 50), system: on(45)))
        #expect(boosts(settings: PolicySettings(batteryGuard: .off), system: on(5)))
        // The adapter is never "on battery".
        #expect(boosts(system: SystemSnapshot(power: PowerState(source: .adapter, batteryPercent: 5, isLowPowerMode: false))))
    }

    @Test func row13Schedule() {
        let day = PolicySettings(schedule: ScheduleWindow(startMinute: 480, endMinute: 1200))
        #expect(stopsOnlyTheBoostHalf(.outsideSchedule, settings: day, minuteOfDay: 1260))
        #expect(boosts(settings: day, minuteOfDay: 480) && !boosts(settings: day, minuteOfDay: 1200))
        let night = PolicySettings(schedule: ScheduleWindow(startMinute: 1320, endMinute: 360))   // spans midnight
        #expect(boosts(settings: night, minuteOfDay: 30) && !boosts(settings: night, minuteOfDay: 600))
        #expect(boosts(minuteOfDay: 1439))
    }

    @Test func row14FullScreenVideoOnThisDisplay() {
        let video = SystemSnapshot(power: T.adapter, fullScreenDisplays: [builtInKey], fullScreenVideoDisplays: [builtInKey])
        let rule = PolicySettings(pauseForFullScreenVideo: true)
        #expect(boosts(system: video))                                                       // off by default
        #expect(stopsOnlyTheBoostHalf(.fullScreenVideo, settings: rule, system: video))
        // Only the display that shows the video pauses.
        let other = T.display(DisplayFixture.proDisplayXDR.displays[0])
        let decision = decide([T.display(), other], settings: rule, system: video)
        #expect(decision.builtIn?.reasons == [.fullScreenVideo])
        #expect(decision.displays[DisplayFixture.Keys.proDisplayXDR]?.boostGain != nil)
    }

    @Test func row15EveryFullScreenApp() {
        let fullScreen = SystemSnapshot(power: T.adapter, fullScreenDisplays: [builtInKey])
        #expect(boosts(system: fullScreen))                                                 // off by default
        #expect(stopsOnlyTheBoostHalf(.fullScreenApp, settings: PolicySettings(pauseForAllFullScreen: true),
                                      system: fullScreen))
    }

    @Test func row16PausedApps() {
        let rules = PolicySettings(pauseForListedApps: true,
                                   pausedApps: [PausedAppRule(bundleID: "com.example.Player", mode: .whilePlaying),
                                                PausedAppRule(bundleID: "com.example.Editor", mode: .whileFrontmost),
                                                PausedAppRule(bundleID: "com.example.Off", mode: .whileFrontmost,
                                                              isEnabled: false)])
        func front(_ id: String, playing: Bool? = nil, on displays: Set<DisplayKey>? = nil) -> SystemSnapshot {
            SystemSnapshot(power: T.adapter, frontmost: T.front(id, on: displays ?? [builtInKey], isPlaying: playing))
        }
        #expect(stopsOnlyTheBoostHalf(.pausedApp(bundleID: "com.example.Editor"), settings: rules,
                                      system: front("com.example.Editor")))
        #expect(stopsOnlyTheBoostHalf(.pausedApp(bundleID: "COM.example.editor"), settings: rules,
                                      system: front("COM.example.editor")))                 // case-insensitive
        #expect(stopsOnlyTheBoostHalf(.pausedApp(bundleID: "com.example.Player"), settings: rules,
                                      system: front("com.example.Player", playing: true)))
        #expect(boosts(settings: rules, system: front("com.example.Player", playing: false)))
        #expect(!boosts(settings: rules, system: front("com.example.Player", playing: nil)))   // unknown: in front
        #expect(boosts(settings: rules, system: front("com.example.Off")))                    // rule disabled
        #expect(boosts(settings: rules, system: front("com.example.PlayerPro")))              // exact IDs only
        #expect(boosts(settings: rules, system: front("com.example.Editor", on: [])))         // menu bar only
        #expect(boosts(settings: rules, system: front("com.example.Editor", on: [DisplayFixture.Keys.mpg322ux])))
        var listOff = rules
        listOff.pauseForListedApps = false
        #expect(boosts(settings: listOff, system: front("com.example.Editor")))
    }

    @Test func row17Games() {
        let game = SystemSnapshot(power: T.adapter, frontmost: T.front("com.example.Game", on: [builtInKey], isGame: true))
        #expect(boosts(system: game))                                                       // off by default
        #expect(stopsOnlyTheBoostHalf(.game, settings: PolicySettings(pauseInGames: true), system: game))
        let elsewhere = SystemSnapshot(power: T.adapter, frontmost: T.front("com.example.Game", on: [], isGame: true))
        #expect(boosts(settings: PolicySettings(pauseInGames: true), system: elsewhere))
    }

    @Test func row18OLEDIdle() {
        let idle = SystemSnapshot(power: T.adapter, isIdleBeyondThreshold: true)
        let msi = { (level: LevelPosition) in
            self.decide([T.display(T.msi, level: level, boostEnabled: true)], system: idle)
                .displays[DisplayFixture.Keys.mpg322ux]
        }
        #expect(msi(brightRoom)?.target == .neutral && msi(brightRoom)?.reasons == [.oledIdle])
        #expect(msi(dimHalf)?.dimLight != nil)
        #expect(boosts(system: idle))                                                       // not OLED
        let overridden = decide([T.display(oled: .oled)], system: idle).builtIn
        #expect(overridden?.reasons.contains(.oledIdle) == true)
    }

    /// Row 19 as built (2026-10-20): macOS asking the app to suppress HDR is no reason at all. macOS 27 sends a
    /// menu-bar agent that request from launch while the headroom our trigger asks for is granted and the boost works,
    /// so "Limited by macOS" only hid the real ceiling; a suppression that does lower the grant shows as the headroom
    /// term, measured.
    @Test func row19HDRSuppressionIsNoReason() {
        let suppressed = SystemSnapshot(power: T.adapter, isHDRSuppressed: true)
        let decision = builtIn(brightRoom, system: suppressed)
        #expect(decision?.boostGain != nil && decision?.reasons == [])
        #expect(builtIn(dimHalf, system: suppressed)?.reasons == [])
    }

    /// A boost while macOS asks to suppress HDR reports the Safe limit when Safe binds (outdoors, H 1.6), never
    /// "Limited by macOS" (the owner's built-in boosted to ×1.237 at Safe that way, 2026-10-20).
    @Test func aSuppressedBoostReportsTheSafeLimit() {
        let suppressed = SystemSnapshot(power: T.adapter, isHDRSuppressed: true)
        let display = T.display(level: brightRoom, reading: T.reading(T.builtIn, current: 1.6))
        let decision = decide([display], system: suppressed).builtIn
        #expect(decision?.boostGain != nil)
        #expect(decision?.reasons == [.safeLimit])
        #expect(decision?.reasons.contains(.hdrSuppressedByMacOS) == false)
    }

    /// Every matching reason is kept in precedence order; the first stop decides and is the chip.
    @Test func reasonsKeepThePrecedenceOrder() {
        let until = T.now.addingTimeInterval(600)
        let system = SystemSnapshot(power: PowerState(source: .battery, batteryPercent: 10, isLowPowerMode: true),
                                    thermal: .critical, isScreenLocked: true, focus: .off, isHDRSuppressed: true)
        let decision = builtIn(brightRoom, system: system, pausedUntil: until, trip: .oscillation, boostEnabled: false)
        #expect(decision?.reasons == [.shielded, .tripped(.oscillation), .userPaused(until: until), .focusOff,
                                      .boostNotEnabled, .thermalCritical, .lowPowerMode,
                                      .battery(percent: 10, threshold: 20)])
        #expect(builtIn(dimHalf, system: system, pausedUntil: until, trip: .oscillation)?.reasons
                == [.shielded, .tripped(.oscillation), .userPaused(until: until), .focusOff])
    }

    // MARK: Step 7

    @Test func capsAndTheirReasons() {
        let serious = SystemSnapshot(power: T.adapter, thermal: .serious)
        #expect(builtIn(brightRoom, system: serious)?.target == .boost(gain: 1.2))
        #expect(builtIn(brightRoom, system: serious)?.reasons == [.thermalSerious])
        #expect(builtIn(max, system: serious)?.reasons == [.thermalSerious, .safeLimit])
        #expect(builtIn(LevelPreset.indoor.position, system: serious)?.reasons == [])          // ×1.136 < ×1.2
        // Safe binds at the top (p ≥ 0.98) where Peak would give more; never in Peak.
        #expect(abs((builtIn(max)?.boostGain ?? 0) - 1.667) < 0.0005 && builtIn(max)?.reasons == [.safeLimit])
        #expect(builtIn(LevelPosition(0.98))?.reasons == [.safeLimit] && builtIn(LevelPosition(0.97))?.reasons == [])
        #expect(builtIn(max, capMode: .peak)?.reasons == [])
        // Studio Display XDR in Safe: no boost half; Peak boosts.
        let studio = DisplayFixture.studioDisplayXDR.displays[0]
        let studioSafe = decide([T.display(studio, level: brightRoom)]).displays[DisplayFixture.Keys.studioDisplayXDR]
        #expect(studioSafe?.target == .neutral && studioSafe?.reasons == [.safeLimit])
        #expect(decide([T.display(studio, level: brightRoom, capMode: .peak)])
                    .displays[DisplayFixture.Keys.studioDisplayXDR]?.boostGain != nil)
        // OLED Safe binds as the OLED limit.
        let oled = decide([T.display(T.msi, level: max, boostEnabled: true)]).displays[DisplayFixture.Keys.mpg322ux]
        #expect(oled?.target == .boost(gain: 1.3) && oled?.reasons == [.oledLimit])
    }

    /// With a trusted SDR white, Safe's static term `capNits ÷ sdrNow` is exact (§5.4, §5.6 outdoors row).
    @Test func aTrustedSDRWhiteCapsSafe() {
        func decision(_ nits: Double, mode: CapMode = .safe) -> DisplayDecision? {
            decide([T.display(level: brightRoom, capMode: mode, sdrWhite: SDRWhiteEstimate(nits: nits, source: .colorimeter))])
                .builtIn
        }
        #expect(decision(1000)?.target == .neutral && decision(1000)?.reasons == [.safeLimit])  // outdoors
        #expect(decision(800)?.target == .boost(gain: 1.25) && decision(800)?.reasons == [.safeLimit])
        #expect(abs((decision(600)?.boostGain ?? 0) - 1.291) < 0.0005 && decision(600)?.reasons == [])
        #expect(abs((decision(1000, mode: .peak)?.boostGain ?? 0) - 1.608) < 0.0005)          // no Safe term in Peak
    }

    /// The live terms come from the feedback reading through `liveCap`; the target stays the static gain.
    @Test func liveReasonsFromTheFeedbackReading() {
        func decision(_ h: Double, level: LevelPosition, mode: CapMode = .safe,
                      taper: Bool = true) -> DisplayDecision? {
            let reading = T.reading(T.builtIn, current: h)
            return decide([T.display(level: level, capMode: mode, reading: reading)],
                          settings: PolicySettings(boostOnlyNearFullBrightness: taper)).builtIn
        }
        let outdoorsPeak = decision(1.6, level: max, mode: .peak)
        #expect(abs((outdoorsPeak?.boostGain ?? 0) - 2.587) < 0.0005 && outdoorsPeak?.reasons == [.headroom])
        #expect(decision(1.6, level: brightRoom)?.reasons == [.safeLimit])                    // the live Safe bound
        #expect(decision(1600.0 / 300, level: brightRoom)?.reasons == [.nearFullBrightnessOnly])
        #expect(decision(1600.0 / 300, level: brightRoom, taper: false)?.reasons == [])
        #expect(decide([T.display(level: brightRoom, reading: .some(nil))]).builtIn?.target == .neutral)  // checking
    }

    /// The taper's reference is the engine's (the feedback's learned lowest ready H), floored at the seed
    /// `panelPeak ÷ sdrMax` (`GainCeiling.taperReference`, 2026-10-20): a reference below the seed reads as the seed, a
    /// reference above it is used as it is. On the M4 Max (seed 2.667) at H 4.0 the seed tapers the boost; a measured
    /// 1.31 (a ready reading taken while the grant was still ramping) tapers it exactly as much, not to nothing; a
    /// measured 3.6 keeps the full gain (C-BOOST-7). The taper is on explicitly: it is off by default.
    @Test func theTaperReferenceComesFromTheFeedback() {
        func reasons(_ h: Double, reference: Double?, capMode: CapMode = .safe) -> [LimitReason]? {
            var display = T.display(level: brightRoom, capMode: capMode, reading: T.reading(T.builtIn, current: h))
            display.feedback.fullBrightnessHeadroom = reference
            return decide([display], settings: PolicySettings(boostOnlyNearFullBrightness: true)).builtIn?.reasons
        }
        #expect(reasons(2.2, reference: nil) == [])                                         // the seed
        #expect(reasons(2.2, reference: 1.6) == [])                                         // below the seed: the seed
        #expect(reasons(4.0, reference: nil) == [.nearFullBrightnessOnly])                  // H 1.5 × the seed
        #expect(reasons(4.0, reference: 1.31) == [.nearFullBrightnessOnly])                 // floored, not t = 0
        #expect(reasons(4.0, reference: 3.6) == [])                                         // above the seed: used
        #expect(reasons(1.7, reference: 1.6, capMode: .peak) == [])                         // ≤ 1.15 × H_full
        #expect(decide([T.display(level: brightRoom, reading: T.reading(T.builtIn, current: 4.0))]).builtIn?.reasons
                == [])                                                                      // the default: no taper
    }

    /// Property: for any reading, reference, level, cap mode and taper setting, the reducer reports a live term
    /// exactly when `GainCeiling.liveCap` with the same reference (the call `TableWriter` makes) binds it, so the chip
    /// always explains what the writer applies (C-BOOST-7).
    @Test func theLiveReasonIsTheWritersLiveCap() {
        var random = SeededGenerator(seed: 0x0B21_E7F7)
        var checked = 0
        for _ in 0..<2_000 {
            let h = Double.random(in: 1.0...6.0, using: &random)
            let reference: Double? = Bool.random(using: &random) ? nil : Double.random(in: 1.1...3.2, using: &random)
            let capMode: CapMode = Bool.random(using: &random) ? .safe : .peak
            let taper = Bool.random(using: &random)
            let level = LevelPosition(Double.random(in: 0.05...1, using: &random))
            var display = T.display(level: level, capMode: capMode, reading: T.reading(T.builtIn, current: h))
            display.feedback.fullBrightnessHeadroom = reference
            let settings = PolicySettings(boostOnlyNearFullBrightness: taper)
            guard let decision = decide([display], settings: settings).builtIn, case .boost(let gain) = decision.target,
                  let reading = display.feedback.lastReading else { continue }
            let cap = GainCeiling.liveCap(
                staticGain: gain, reading: reading, facts: display.facts, capMode: capMode, isOLED: false, sdrWhite: nil,
                taper: taper, fullBrightnessHeadroom: reference ?? GainCeiling.fullBrightnessHeadroomSeed(facts: display.facts))
            for live in [LimitReason.nearFullBrightnessOnly, .headroom] {
                #expect(decision.reasons.contains(live) == (cap.reason == live),
                        "H \(h), reference \(String(describing: reference)), \(capMode), taper \(taper)")
            }
            checked += 1
        }
        #expect(checked > 500)
    }

    /// Step 3 and the no-op rule: linked levels, the Focus level, and gains below ×1.005.
    @Test func effectiveLevels() {
        let pro = DisplayFixture.proDisplayXDR.displays[0]
        let linked = decide([T.display(level: .standard), T.display(pro, level: LevelPosition(-0.5))],
                            settings: PolicySettings(linkLevels: true, linkedLevel: max))
        #expect(abs((linked.builtIn?.boostGain ?? 0) - 1.667) < 0.0005 && linked.builtIn?.level == max)
        #expect(abs((linked.displays[DisplayFixture.Keys.proDisplayXDR]?.boostGain ?? 0) - 2.0) < 0.0005)  // own top
        let focus = decide([T.display(level: max), T.display(pro, level: max)],
                           system: SystemSnapshot(power: T.adapter, focus: .on(level: dimHalf)))
        #expect(focus.displays.values.allSatisfy { abs(($0.dimLight ?? 0) - 0.501) < 0.0005 && $0.level == dimHalf })
        #expect(builtIn(LevelPosition(0.005))?.target == .neutral)                            // ×1.0026: a no-op
        #expect(builtIn(LevelPosition(0.02))?.boostGain != nil)                               // ×1.0103
        #expect(builtIn(LevelPosition(-1))?.dimLight == 0.02)
    }

    /// Compatibility mode is unavailable (`MechanismPreference.overlayIsAvailable`, 2026-10-20: the overlay turned the
    /// owner's built-in white): Automatic on a compatibility model, an explicit Compatibility-mode preference and a
    /// "did not get brighter" record all give the table, and no display carries the advisory (§7.5).
    @Test func overlayIsNeverChosenWhileUnavailable() {
        #expect(!MechanismPreference.overlayIsAvailable)
        #expect(builtIn(brightRoom, mechanism: .overlay)?.mechanism == .table)
        #expect(builtIn(brightRoom, mechanism: .table)?.mechanism == .table)
        let neo = DisplayFixture.neoIgnoresWrites
        let onNeo = decide([T.display(neo.displays[0])], machine: neo.machine).builtIn
        #expect(onNeo?.mechanism == .table && onNeo?.boostGain != nil)
        #expect(onNeo?.eligibility.advisories.contains(.compatibilityModeAdvised) == false)
        #expect(decide([T.display(neo.displays[0], mechanism: .overlay)], machine: neo.machine).builtIn?.mechanism
                == .table)
        let notBrighter = T.display(calibration: T.record(.notBrighter))
        #expect(decide([notBrighter]).builtIn?.mechanism == .table)
    }
}
