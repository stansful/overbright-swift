// OverbrightPanelUI/QA/ScriptedGallery+More.swift — the banner, per-display pause, edge-case, window and HUD states of
// DESIGN.md §5.13. Conflicting apps have invented names (a long one and a right-to-left one, D3).
import Foundation
import OverbrightCore
import OverbrightPolicy

extension ScriptedGallery {
    /// The global banners: every display held by the same reason, said once (no chip repeats it).
    static func bannerStates(booster: ConflictingApp, colorApp: ConflictingApp, schedule: ScheduleWindow)
        -> [ScriptedState] {
        let pairStatuses = [P.builtInBoosted(1.291), P.msiStandard()]
        func banner(_ name: String, _ reason: LimitReason, _ banner: Banner, symbol: StatusSymbolState = .paused,
                    pausedUntil: Date? = nil) -> ScriptedState {
            ScriptedState(name: name, status: P.status(P.held(pairStatuses, by: reason), symbol: symbol, banner: banner,
                                                       pausedUntil: pausedUntil),
                          facts: pair, configure: builtInBrightRoom)
        }
        let until = P.now.addingTimeInterval(3600)
        return [
            banner("banner-battery", .battery(percent: 15, threshold: 20), .battery(percent: 15, threshold: 20)),
            banner("banner-low-power", .lowPowerMode, .lowPowerMode),
            banner("banner-heat", .thermalCritical, .thermalCritical),
            banner("banner-paused", .userPaused(until: until), .userPaused(until: until), pausedUntil: until),
            banner("banner-focus", .focusOff, .focusOff),
            banner("banner-schedule", .outsideSchedule, .outsideSchedule(schedule)),
            banner("conflict-booster", .conflict(booster), .conflict(booster), symbol: .attention),
            banner("conflict-color-app", .conflict(colorApp), .conflict(colorApp), symbol: .attention),
        ]
    }

    /// Per-display reasons: chips while the other display boosts.
    static func perDisplayStates(mayInterfere: ConflictingApp) -> [ScriptedState] {
        let msiBoosting = P.msiBoosted(1.14)
        func paused(_ name: String, _ reason: LimitReason) -> ScriptedState {
            ScriptedState(name: name, status: P.status(P.held([P.builtInBoosted(1.291)], by: reason) + [msiBoosting]),
                          facts: pair, configure: { settings in builtInBrightRoom(settings); msiOn(0.5)(settings) })
        }
        let flicker = P.display(P.builtIn, phase: .failed(.oscillation), reasons: [.tripped(.oscillation)],
                                eligibility: P.eligibility(P.builtInVerdict, advisories: [.notCalibrated]), requested: 1.291)
        let foreign = P.display(P.builtIn, phase: .failed(.foreignTableAtLaunch), reasons: [.tripped(.foreignTableAtLaunch)],
                                eligibility: P.eligibility(P.builtInVerdict, advisories: [.notCalibrated]), requested: 1.291)
        var oledIdle = P.held([msiBoosting], by: .oledIdle)
        oledIdle.insert(P.builtInBoosted(1.291), at: 0)
        return [
            ScriptedState(name: "heat-cap", status: P.status([P.builtInBoosted(1.2, reasons: [.thermalSerious], requested: 1.291),
                                                              P.msiStandard()]),
                          facts: pair, configure: builtInBrightRoom),
            ScriptedState(name: "conflict-may-interfere",
                          status: P.status([P.builtInBoosted(1.291, reasons: [.conflict(mayInterfere)]), P.msiStandard()]),
                          facts: pair, configure: builtInBrightRoom),
            ScriptedState(name: "flicker-stop", status: P.status([flicker, P.msiStandard()], symbol: .attention,
                                                                 banner: .flickerStop(display: P.builtIn.ref.key)),
                          facts: pair, configure: builtInBrightRoom),
            ScriptedState(name: "foreign-table", status: P.status([foreign, P.msiStandard()], symbol: .attention,
                                                                  banner: .foreignTableAtLaunch),
                          facts: pair, configure: builtInBrightRoom),
            paused("full-screen-video", .fullScreenVideo),
            paused("full-screen", .fullScreenApp),
            paused("paused-app", .pausedApp(bundleID: "com.example.long-named-video-player-for-testing")),
            ScriptedState(name: "oled-idle", status: P.status(oledIdle), facts: pair,
                          configure: { settings in builtInBrightRoom(settings); msiOn(0.5)(settings) }),
            ScriptedState(name: "compatibility",
                          status: P.status([P.display(P.builtIn, phase: .boosted, target: .boost(gain: 1.291),
                                                      eligibility: P.eligibility(P.builtInVerdict,
                                                                                 advisories: [.compatibilityModeAdvised, .notCalibrated],
                                                                                 mechanism: .overlay),
                                                      mechanism: .overlay, gain: 1.291,
                                                      reading: P.reading(P.builtIn, current: 2.667, potential: 16))]),
                          facts: [P.builtIn], configure: builtInBrightRoom),
        ]
    }

    /// Names, counts and the empty state.
    static var edgeStates: [ScriptedState] {
        let sidecar = P.display(P.sidecar, eligibility: P.eligibility(.virtualDisplay, boostByDefault: false))
        let lcd = P.display(P.lcd, eligibility: P.eligibility(.lcdClass, boostByDefault: false))
        let msiOff = P.display(P.msiHDROff, eligibility: P.eligibility(.turnOnHDR, advisories: [.oledCare],
                                                                        boostByDefault: false))
        let twin = P.display(P.msiTwin, eligibility: P.eligibility(P.msiVerdict, advisories: [.oledCare, .notCalibrated],
                                                                   boostByDefault: false))
        let pro = P.display(P.proDisplay, phase: .boosted, target: .boost(gain: 1.414),
                            eligibility: P.eligibility(P.proVerdict, advisories: [.notCalibrated]), gain: 1.414,
                            reading: P.reading(P.proDisplay, current: 3.2, potential: 16))
        let studio = P.display(P.studioDisplay, eligibility: P.eligibility(P.studioVerdict, advisories: [.notCalibrated]))
        return [
            ScriptedState(name: "why-expanded", status: P.status([P.builtInBoosted(1.291), sidecar]),
                          facts: [P.builtIn, P.sidecar], configure: builtInBrightRoom, expandsWhy: true),
            ScriptedState(name: "nothing-capable", status: P.status([lcd, msiOff, sidecar]),
                          facts: [P.lcd, P.msiHDROff, P.sidecar], configure: levels([P.lcd.ref.key: 0, P.msi.ref.key: 0]),
                          expandsWhy: true),
            ScriptedState(name: "two-identical-externals", status: P.status([P.builtInBoosted(1.291), P.msiStandard(), twin]),
                          facts: [P.builtIn, P.msi, P.msiTwin],
                          configure: levels([P.builtIn.ref.key: 0.5, P.msi.ref.key: 0, P.msiTwin.ref.key: 0])),
            ScriptedState(name: "long-russian-name",
                          status: P.status([P.builtInBoosted(1.291, facts: P.builtInRussian), P.msiStandard()]),
                          facts: [P.builtInRussian, P.msi], configure: builtInBrightRoom),
            ScriptedState(name: "fill-light-card", status: P.status([P.builtInBoosted(1.291), P.msiStandard()]),
                          facts: pair, configure: builtInBrightRoom, fillLightOn: true),
            ScriptedState(name: "calibration-tip", status: P.status([P.builtInBoosted(1.291), P.msiStandard()]),
                          facts: pair, configure: { settings in
                              builtInBrightRoom(settings)
                              settings[OnboardingSettings.calibrationTipShown] = false
                          }),
            ScriptedState(name: "four-displays", status: P.status([P.builtInBoosted(1.291), P.msiStandard(), pro, studio]),
                          facts: [P.builtIn, P.msi, P.proDisplay, P.studioDisplay],
                          configure: levels([P.builtIn.ref.key: 0.5, P.msi.ref.key: 0, P.proDisplay.ref.key: 0.5,
                                             P.studioDisplay.ref.key: 0])),
            ScriptedState(name: "menubar-hidden", status: P.status([P.builtInBoosted(1.291)]), facts: [P.builtIn],
                          configure: builtInBrightRoom),
            ScriptedState(name: "move-to-applications",
                          status: P.status([P.display(P.builtIn, eligibility: P.eligibility(P.builtInVerdict))], isOn: false),
                          facts: [P.builtIn]),
        ]
    }

    /// The HUD (and the Keep-this-level prompt) states: the panel behind them is ordinary.
    static var hudStates: [ScriptedState] {
        let key = P.builtIn.ref.key
        let dim = P.display(P.builtIn, phase: .dimmed, target: .dim(light: 0.25),
                            eligibility: P.eligibility(P.builtInVerdict, advisories: [.notCalibrated]), gain: 0.25)
        let standard = P.display(P.builtIn, eligibility: P.eligibility(P.builtInVerdict))
        let preparing = P.display(P.builtIn, phase: .arming(rung: 1), target: .boost(gain: 1.291), reasons: [.waitingForHeadroom],
                                  eligibility: P.eligibility(P.builtInVerdict, advisories: [.notCalibrated]), requested: 1.291)
        func hud(_ name: String, _ displays: [DisplayStatus], _ change: LevelChange, isOn: Bool = true,
                 symbol: StatusSymbolState? = nil, levels: [DisplayKey: Double] = [P.builtIn.ref.key: 0.5]) -> ScriptedState {
            ScriptedState(name: name, status: P.status(displays, isOn: isOn, symbol: symbol, lastChange: change),
                          facts: displays.map(\.key).compactMap { k in [P.builtIn, P.msi].first { $0.ref.key == k } },
                          configure: ScriptedGallery.levels(levels))
        }
        let low = LowLevelConfirmation(display: key, previousLevels: [key: LevelPosition(0.5)],
                                       deadline: P.now.addingTimeInterval(10))
        let lowLight = LevelMapping.position(forDimLight: 0.05)
        return [
            hud("hud-boost", [P.builtInBoosted(1.291)], P.change(.level)),
            hud("hud-dim", [dim], P.change(.level), symbol: .dimming, levels: [key: P.dimmed25.value]),
            hud("hud-standard", [standard], P.change(.level), levels: [key: 0]),
            hud("hud-off", [standard], P.change(.level), isOn: false),
            hud("hud-preparing", [preparing], P.change(.preparing, source: .statusItem), symbol: .preparing),
            hud("hud-blocked", P.held([P.builtInBoosted(1.291)], by: .lowPowerMode), P.change(.blocked(.lowPowerMode)),
                symbol: .paused),
            hud("hud-two-displays", [P.builtInBoosted(1.291), P.msiStandard()], P.change(.level, display: key),
                levels: [key: 0.5, P.msi.ref.key: 0]),
            hud("hud-automation-timer", [standard], P.change(.timerEnded, source: .automation), isOn: false),
            hud("hud-automation-battery", P.held([P.builtInBoosted(1.291)], by: .battery(percent: 15, threshold: 20)),
                P.change(.automationStopped(.battery(percent: 15, threshold: 20)), source: .automation), symbol: .paused),
            hud("hud-automation-low-power", P.held([P.builtInBoosted(1.291)], by: .lowPowerMode),
                P.change(.automationStopped(.lowPowerMode), source: .automation), symbol: .paused),
            hud("hud-automation-heat", [P.builtInBoosted(1.2, reasons: [.thermalSerious], requested: 1.291)],
                P.change(.automationStopped(.thermalSerious), source: .automation)),
            hud("hud-automation-schedule", P.held([P.builtInBoosted(1.291)], by: .outsideSchedule),
                P.change(.automationStopped(.outsideSchedule), source: .automation), symbol: .paused),
            hud("hud-automation-back", [P.builtInBoosted(1.291)], P.change(.automationResumed, source: .automation)),
            ScriptedState(name: "keep-level",
                          status: P.status([P.display(P.builtIn, phase: .dimmed, target: .dim(light: 0.05),
                                                      eligibility: P.eligibility(P.builtInVerdict), gain: 0.05)],
                                           symbol: .dimming, pendingLowLevel: low),
                          facts: [P.builtIn], configure: ScriptedGallery.levels([key: lowLight.value])),
        ]
    }
}
