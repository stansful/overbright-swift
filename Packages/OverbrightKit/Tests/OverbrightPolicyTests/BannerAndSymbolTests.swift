// OverbrightPolicyTests/BannerAndSymbolTests.swift — the one banner (ARCHITECTURE.md §6.3, DESIGN.md §12.3) and the menu
// bar symbol (§6.4, DESIGN.md §4.1).
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightPolicy

@Suite struct BannerAndSymbolTests {
    private typealias T = PolicyTestInputs
    private let brightRoom = LevelPreset.brightRoom.position
    private let dimHalf = LevelPosition(-0.5)
    private let pro = DisplayFixture.proDisplayXDR.displays[0]
    private let studio = DisplayFixture.studioDisplayXDR.displays[0]

    private func reduce(_ displays: [DisplayPolicyInput] = [T.display()], master: Bool = true,
                        settings: PolicySettings = PolicySettings(), system: SystemSnapshot = T.system(),
                        pausedUntil: Date? = nil, minuteOfDay: Int = 600) -> PolicyDecision {
        BoostPolicy.reduce(T.input(displays, master: master, settings: settings, system: system, pausedUntil: pausedUntil,
                                   minuteOfDay: minuteOfDay))
    }

    /// The §6.3 order, shown by removing the winner one cause at a time.
    @Test func bannerPrecedence() {
        let booster = T.app(.booster)
        let culprit = T.app(.conditional, entry: "culprit")
        let schedule = ScheduleWindow(startMinute: 480, endMinute: 1200)
        func banner(removing removed: Int) -> Banner? {
            let displays = [T.display(trip: removed < 2 ? .foreignTableAtLaunch : nil),
                            T.display(pro, trip: removed < 3 ? .oscillation : nil),
                            T.display(studio, capMode: .peak, trip: removed < 4 ? .attributedDrift(culprit) : nil)]
            let power = PowerState(source: .battery, batteryPercent: removed < 8 ? 10 : 90, isLowPowerMode: removed < 7)
            let system = SystemSnapshot(power: power, thermal: removed < 6 ? .critical : .nominal,
                                        conflicts: removed < 1 ? [booster] : [], focus: removed < 5 ? .off : .leaveAlone)
            return reduce(displays, settings: PolicySettings(schedule: schedule), system: system, minuteOfDay: 1300)
                .banner
        }
        let expected: [Banner?] = [.conflict(booster), .foreignTableAtLaunch, .flickerStop(display: pro.key),
                                   .attributedDrift(culprit, display: studio.key), .focusOff, .thermalCritical,
                                   .lowPowerMode, .battery(percent: 10, threshold: 20), .outsideSchedule(schedule)]
        for (removed, expectedBanner) in expected.enumerated() {
            #expect(banner(removing: removed) == expectedBanner, "after removing \(removed) causes")
        }
        // A user pause outranks everything, and shows at any level.
        let until = T.now.addingTimeInterval(900)
        #expect(reduce(system: SystemSnapshot(power: T.adapter, conflicts: [booster]), pausedUntil: until).banner
                == .userPaused(until: until))
        #expect(reduce([T.display(level: .standard)], pausedUntil: until).banner == .userPaused(until: until))
        // On battery (adapter only) outranks the schedule.
        let battery = SystemSnapshot(power: PowerState(source: .battery, batteryPercent: 90, isLowPowerMode: false))
        #expect(reduce(settings: PolicySettings(batteryGuard: .onlyOnAdapter, schedule: schedule), system: battery,
                       minuteOfDay: 1300).banner == .onBattery)
        // Repairs exceeded is the unattributed drift; ties go to the first display.
        #expect(reduce([T.display(trip: .repairBudgetExceeded), T.display(pro, trip: .oscillation)]).banner
                == .unattributedDrift(display: DisplayFixture.Keys.builtIn))
    }

    /// A schedule whose From equals its To is the whole day (C-PLATFORM-2): the Settings pickers pass through equal
    /// ends while either is stepped, and "allowed from 08:00 to 08:00" must never block extra brightness for good.
    @Test func aScheduleFromAMinuteToTheSameMinuteIsTheWholeDay() {
        for minute in [0, 480, 1439] {
            let allDay = ScheduleWindow(startMinute: minute, endMinute: minute)
            #expect((0..<1440).allSatisfy { allDay.contains(minuteOfDay: $0) }, "\(minute)")
            for now in [0, minute, (minute + 720) % 1440, 1439] {
                let decision = reduce(settings: PolicySettings(schedule: allDay), minuteOfDay: now)
                #expect(decision.banner == nil, "\(minute) at \(now)")
                let builtIn = decision.displays[DisplayFixture.Keys.builtIn]
                #expect(builtIn?.reasons.contains(.outsideSchedule) == false)
                guard case .boost? = builtIn?.target else { Issue.record("not boosting: \(minute) at \(now)"); continue }
            }
        }
        // One minute apart is still a window of one minute, or of all but one.
        let oneMinute = ScheduleWindow(startMinute: 480, endMinute: 481)
        #expect(oneMinute.contains(minuteOfDay: 480) && !oneMinute.contains(minuteOfDay: 481))
        let allButOne = ScheduleWindow(startMinute: 481, endMinute: 480)
        #expect(!allButOne.contains(minuteOfDay: 480) && allButOne.contains(minuteOfDay: 481))
        #expect(reduce(settings: PolicySettings(schedule: oneMinute), minuteOfDay: 600).banner
                == .outsideSchedule(oneMinute))
    }

    /// Only reasons that stop a display that would otherwise change raise a banner.
    @Test func bannersNeedADisplayThatWouldChange() {
        let lowPower = SystemSnapshot(power: PowerState(source: .adapter, batteryPercent: nil, isLowPowerMode: true))
        #expect(reduce(system: lowPower).banner == .lowPowerMode)
        #expect(reduce([T.display(level: dimHalf)], system: lowPower).banner == nil)              // dimming continues
        #expect(reduce([T.display(level: .standard)], system: lowPower).banner == nil)
        #expect(reduce([T.display(studio, level: brightRoom)], system: lowPower).banner == nil)   // Safe adds nothing
        let hdrOff = DisplayFixture.mpg322uxHDROff.displays[0]
        #expect(reduce([T.display(hdrOff, boostEnabled: true)], system: lowPower).banner == nil)  // cannot boost anyway
        let conflict = SystemSnapshot(power: T.adapter, conflicts: [T.app(.gammaWriter)])
        #expect(reduce([T.display(level: .standard)], system: conflict).banner == nil)
        #expect(reduce([T.display(level: dimHalf)], system: conflict).banner == .conflict(T.app(.gammaWriter)))
        // A table left by another app is shown whatever the level.
        #expect(reduce([T.display(level: .standard, trip: .foreignTableAtLaunch)]).banner == .foreignTableAtLaunch)
        #expect(reduce([T.display(level: .standard, trip: .oscillation)]).banner == nil)
    }

    /// Per-display reasons are chips, never banners; master off shows no banner at all.
    @Test func noBannerForPerDisplayReasonsOrWhileOff() {
        let key = DisplayFixture.Keys.builtIn
        let video = SystemSnapshot(power: T.adapter, fullScreenVideoDisplays: [key], conflicts: [T.app(.conditional)])
        #expect(reduce(system: video).banner == nil)
        #expect(reduce([T.display(trip: .headroomNeverArrived)]).banner == nil)
        #expect(reduce([T.display(boostEnabled: false)]).banner == nil)
        let everything = SystemSnapshot(power: T.adapter, thermal: .critical, conflicts: [T.app(.booster)], focus: .off)
        #expect(reduce(master: false, system: everything, pausedUntil: T.now.addingTimeInterval(60)).banner == nil)
    }

    @Test func symbolStates() {
        #expect(reduce(master: false).symbol == .off)
        #expect(reduce(master: false, pausedUntil: T.now.addingTimeInterval(60)).symbol == .off)
        #expect(reduce().symbol == .on)
        #expect(reduce([T.display(level: .standard)]).symbol == .on)
        // Attention while a conflict, trip or foreign-table banner is up.
        #expect(reduce(system: SystemSnapshot(power: T.adapter, conflicts: [T.app(.booster)])).symbol == .attention)
        #expect(reduce([T.display(trip: .oscillation)]).symbol == .attention)
        #expect(reduce([T.display(trip: .attributedDrift(T.app(.conditional)))]).symbol == .attention)
        #expect(reduce([T.display(level: .standard, trip: .foreignTableAtLaunch)]).symbol == .attention)
        // A user pause, even with a conflict (the pause banner wins).
        let until = T.now.addingTimeInterval(60)
        #expect(reduce(pausedUntil: until).symbol == .paused)
        #expect(reduce(system: SystemSnapshot(power: T.adapter, conflicts: [T.app(.booster)]), pausedUntil: until).symbol
                == .paused)
        // Every display that should boost stopped by a global stop or a boost-only guard.
        let lowPower = SystemSnapshot(power: PowerState(source: .adapter, batteryPercent: nil, isLowPowerMode: true))
        #expect(reduce([T.display(), T.display(pro)], system: lowPower).symbol == .paused)
        #expect(reduce(system: SystemSnapshot(power: T.adapter, focus: .off)).symbol == .paused)
        #expect(reduce(system: SystemSnapshot(power: T.adapter, isScreenLocked: true)).symbol == .paused)
        let key = DisplayFixture.Keys.builtIn
        let video = SystemSnapshot(power: T.adapter, fullScreenVideoDisplays: [key])
        let videoRule = PolicySettings(pauseForFullScreenVideo: true)                           // off by default
        #expect(reduce([T.display()], system: video).symbol == .on)
        #expect(reduce([T.display()], settings: videoRule, system: video).symbol == .paused)
        #expect(reduce([T.display(), T.display(pro)], settings: videoRule, system: video).symbol == .on) // the other boosts
        // A boost-only guard with a dimmed display: the boosting display is paused.
        #expect(reduce([T.display(), T.display(pro, level: dimHalf)], system: lowPower).symbol == .paused)
        // Dimming when every changed display is dimmed; a mix with a boost is on.
        #expect(reduce([T.display(level: dimHalf), T.display(pro, level: .standard)]).symbol == .dimming)
        #expect(reduce([T.display(level: dimHalf), T.display(pro)]).symbol == .on)
        #expect(reduce([T.display(level: dimHalf)], system: lowPower).symbol == .dimming)
        // A trip without a banner (no headroom) is not attention: the engine's phase shows it.
        #expect(reduce([T.display(trip: .headroomNeverArrived)]).symbol == .on)
    }

    /// A display whose own "Use extra brightness" switch is off would not change: it is not "paused" in the menu bar
    /// and raises no guard's banner (an opt-in OLED external on a Mac mini, WP13); its chip still says why.
    @Test func aDisplayWhoseSwitchIsOffIsNotPaused() {
        let msi = DisplayFixture.mpg322uxHDROn.displays[0]
        let lowPower = SystemSnapshot(power: PowerState(source: .adapter, batteryPercent: nil, isLowPowerMode: true))
        let notEnabled = reduce([T.display(msi, boostEnabled: false)])
        #expect(notEnabled.symbol == .on)
        #expect(notEnabled.banner == nil)
        #expect(notEnabled.displays[msi.key]?.reasons.first == .boostNotEnabled)
        #expect(reduce([T.display(msi, boostEnabled: false)], system: lowPower).banner == nil)
        #expect(reduce([T.display(msi, boostEnabled: false)], system: lowPower).symbol == .on)
        // Once the user turns it on, the guard pauses it and says so.
        #expect(reduce([T.display(msi, boostEnabled: true)], system: lowPower).symbol == .paused)
        #expect(reduce([T.display(msi, boostEnabled: true)], system: lowPower).banner == .lowPowerMode)
        // Next to a display that boosts, the menu bar shows on.
        #expect(reduce([T.display(), T.display(msi, boostEnabled: false)]).symbol == .on)
    }

    /// The reducer never sets `.preparing` (the engine does, from its phases), whatever the input.
    @Test func neverPreparing() {
        for master in [true, false] {
            for level in [brightRoom, dimHalf, .standard] {
                for reading in [HeadroomReading?.none, T.reading(T.builtIn, granted: false)] {
                    let symbol = reduce([T.display(level: level, reading: .some(reading))], master: master).symbol
                    #expect(symbol != .preparing)
                }
            }
        }
    }
}

