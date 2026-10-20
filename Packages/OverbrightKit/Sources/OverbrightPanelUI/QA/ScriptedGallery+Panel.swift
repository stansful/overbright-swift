// OverbrightPanelUI/QA/ScriptedGallery+Panel.swift — the panel states of DESIGN.md §5.13 (cards, chips, banners,
// phases, edge states). Numbers follow ARCHITECTURE.md §5.3 and §5.6.
import Foundation
import OverbrightCore
import OverbrightPolicy

/// The gallery of named states.
enum ScriptedGallery {
    typealias P = ScriptedParts

    /// The built-in and the MSI, the usual pair.
    static let pair = [P.builtIn, P.msi]

    /// Levels by display (the default level is Bright room).
    static func levels(_ levels: [DisplayKey: Double]) -> @MainActor (SettingsStore) -> Void {
        { settings in
            for (key, value) in levels { ScriptedSettings.set(settings, key) { $0.level = LevelPosition(value) } }
        }
    }

    /// The built-in at Bright room, the MSI at Standard.
    static let builtInBrightRoom = levels([P.builtIn.ref.key: 0.5, P.msi.ref.key: 0])

    /// The built-in calibrated (valid record) and the MSI at Standard.
    static let calibratedBuiltIn: @MainActor (SettingsStore) -> Void = { settings in
        builtInBrightRoom(settings)
        ScriptedSettings.set(settings, P.builtIn.ref.key) { $0.calibration = ScriptedSettings.calibration(potential: 16) }
    }

    /// The MSI with extra brightness on at `level`.
    static func msiOn(_ level: Double, capMode: CapMode = .safe) -> @MainActor (SettingsStore) -> Void {
        { settings in
            ScriptedSettings.set(settings, P.msi.ref.key) {
                $0.boostEnabled = true; $0.oledNoticeAcknowledged = true; $0.level = LevelPosition(level)
                $0.capMode = capMode
            }
        }
    }

    // MARK: States

    static var panelStates: [ScriptedState] {
        let builtInBR = P.builtInBoosted(1.291)
        let booster = P.app("Glow Booster Pro Extended Edition for Professionals", severity: .booster)
        let colorApp = P.app("צבעים חמים", severity: .gammaWriter)
        let mayInterfere = P.app("Display Tuner", severity: .conditional)
        let schedule = ScheduleWindow(startMinute: 480, endMinute: 1200)
        return [
            ScriptedState(id: "off", status: P.status(P.held([P.display(P.builtIn, eligibility: P.eligibility(P.builtInVerdict)),
                                                                  P.msiStandard()], by: .masterOff), isOn: false),
                          facts: pair),
            ScriptedState(id: "standard", status: P.status([P.display(P.builtIn, eligibility: P.eligibility(P.builtInVerdict)),
                                                              P.msiStandard()]),
                          facts: pair, configure: levels([P.builtIn.ref.key: 0, P.msi.ref.key: 0])),
            ScriptedState(id: "boosting", status: P.status([P.builtInBoosted(1.291, advisories: []), P.msiStandard()],
                                                             autoOffAt: P.now.addingTimeInterval(23 * 60)),
                          facts: pair, configure: { settings in
                              calibratedBuiltIn(settings)
                              settings[AutomationSettings.autoOffMinutes] = 30
                          }),
            ScriptedState(id: "boosting-uncalibrated", status: P.status([builtInBR, P.msiStandard()]), facts: pair,
                          configure: builtInBrightRoom),
            ScriptedState(id: "boosting-nits",
                          status: P.status([builtInBR, P.msiBoosted(1.218, sdrWhite: SDRWhiteEstimate(nits: 265.05, source: .hdrFrameAverage),
                                                                    advisories: [.oledCare])]),
                          facts: pair, configure: { settings in
                              builtInBrightRoom(settings)
                              msiOn(0.75)(settings)
                              ScriptedSettings.set(settings, P.msi.ref.key) {
                                  $0.calibration = ScriptedSettings.calibration(potential: 4.6549)
                              }
                          }),
            ScriptedState(id: "limited-by-macos",
                          status: P.status([P.builtInBoosted(0.97 * 1.6, headroom: 1.6, reasons: [.headroom], requested: 1000.0 / 600),
                                            P.msiStandard()]),
                          facts: pair, configure: { settings in
                              ScriptedSettings.set(settings, P.builtIn.ref.key) {
                                  $0.capMode = .peak; $0.level = LevelPosition(log(1000.0 / 600) / log(0.97 * 1600 / 600))
                              }
                              levels([P.msi.ref.key: 0])(settings)
                          }),
            ScriptedState(id: "safe-limit", status: P.status([P.builtInBoosted(1000.0 / 600, reasons: [.safeLimit]),
                                                                P.msiStandard()]),
                          facts: pair, configure: levels([P.builtIn.ref.key: 1, P.msi.ref.key: 0])),
            ScriptedState(id: "safe-limit-hdr-external",
                          status: P.status([P.display(P.hdrExternal, phase: .boosted, target: .boost(gain: 1.4),
                                                      reasons: [.safeLimit],
                                                      eligibility: P.eligibility(P.hdrExternalVerdict, advisories: [.notCalibrated]),
                                                      gain: 1.4, reading: P.reading(P.hdrExternal, current: 2.33, potential: 7))]),
                          facts: [P.hdrExternal], configure: { settings in
                              ScriptedSettings.set(settings, P.hdrExternal.ref.key) { $0.boostEnabled = true; $0.level = LevelPosition(1) }
                          }),
            ScriptedState(id: "safe-limit-oled", status: P.status([P.msiBoosted(1.3, reasons: [.oledLimit])]),
                          facts: [P.msi], configure: msiOn(1)),
            ScriptedState(id: "small-gain", status: P.status([P.msiBoosted(1.14)]), facts: [P.msi], configure: msiOn(0.5)),
            ScriptedState(id: "below-full-brightness",
                          status: P.status([P.builtInBoosted(1.12, headroom: 3.2, reasons: [.nearFullBrightnessOnly], requested: 1.291),
                                            P.msiStandard()]),
                          facts: pair, configure: builtInBrightRoom),
            ScriptedState(id: "preparing",
                          status: P.status([P.display(P.builtIn, phase: .arming(rung: 1), target: .boost(gain: 1.291),
                                                      reasons: [.waitingForHeadroom],
                                                      eligibility: P.eligibility(P.builtInVerdict, advisories: [.notCalibrated]),
                                                      requested: 1.291), P.msiStandard()], symbol: .preparing),
                          facts: pair, configure: builtInBrightRoom),
            ScriptedState(id: "no-extra-range", status: P.status([failed(tries: 1), P.msiStandard()], symbol: .attention),
                          facts: pair, configure: builtInBrightRoom),
            ScriptedState(id: "still-no-extra-range", status: P.status([failed(tries: 2), P.msiStandard()], symbol: .attention),
                          facts: pair, configure: builtInBrightRoom),
            ScriptedState(id: "dimmed",
                          status: P.status([P.display(P.builtIn, phase: .dimmed, target: .dim(light: 0.25),
                                                      eligibility: P.eligibility(P.builtInVerdict, advisories: [.notCalibrated]),
                                                      gain: 0.25), P.msiStandard()], symbol: .dimming),
                          facts: pair, configure: levels([P.builtIn.ref.key: P.dimmed25.value, P.msi.ref.key: 0])),
            ScriptedState(id: "extra-brightness-off",
                          status: P.status([builtInBR, P.msiStandard(reasons: [.boostNotEnabled])]), facts: pair,
                          configure: levels([P.builtIn.ref.key: 0.5, P.msi.ref.key: 0.5])),
            ScriptedState(id: "linked", status: P.status([builtInBR, P.msiBoosted(1.14)]), facts: pair,
                          configure: { settings in
                              settings[DisplaySettings.linkLevels] = true
                              msiOn(0.5)(settings)
                          }),
        ] + bannerStates(booster: booster, colorApp: colorApp, schedule: schedule)
            + perDisplayStates(mayInterfere: mayInterfere,
                               conflicts: conflictStates(booster: booster, colorApp: colorApp)) + edgeStates
    }

    /// The built-in after the ladder failed `tries` times.
    static func failed(tries: Int) -> DisplayStatus {
        P.display(P.builtIn, phase: .failed(.headroomNeverArrived), reasons: [.tripped(.headroomNeverArrived)],
                  eligibility: P.eligibility(P.builtInVerdict, advisories: [.notCalibrated]),
                  requested: 1.291, failedTries: tries)
    }
}
