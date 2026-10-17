// OverbrightCoreTests/ContractTests.swift — the small behaviours of the §3 value types. ARCHITECTURE.md §3.2–§3.7.
import CoreGraphics
import Foundation
import Testing
@testable import OverbrightCore

@Suite struct ContractTests {
    @Test func levelPositionsClampAndCompare() {
        #expect(LevelPosition(3).value == 1 && LevelPosition(-7).value == -1)
        #expect(LevelPosition(.nan) == .standard && LevelPosition(.infinity) == .standard)
        #expect(LevelPosition(0.2).isBoost && LevelPosition(-0.2).isDim && !LevelPosition.standard.isBoost)
        #expect(LevelPosition(-0.5) < .standard && LevelPreset.indoor.position < LevelPreset.max.position)
        #expect(LevelPreset.allCases.map(\.position.value) == [0, 0.25, 0.5, 0.75, 1])
        #expect(DisplayPreferences().level == LevelPreset.brightRoom.position)
    }

    @Test func displayKeysAreUppercasedAndEncodeAsObjectKeys() throws {
        let key = DisplayKey(rawValue: "37d8832a-2d66-02ca-b9f7-8f30a301b230")
        #expect(key.rawValue == "37D8832A-2D66-02CA-B9F7-8F30A301B230" && key == DisplayKey(rawValue: key.rawValue))
        let json = try JSONEncoder().encode([key: 1])
        #expect(String(decoding: json, as: UTF8.self) == "{\"37D8832A-2D66-02CA-B9F7-8F30A301B230\":1}")
        #expect(try JSONDecoder().decode([DisplayKey: Int].self, from: json) == [key: 1])
        let shortcuts = try JSONEncoder().encode([ShortcutID.dimToggle: 9])
        #expect(String(decoding: shortcuts, as: UTF8.self) == "{\"boost.dimToggle\":9}")
        #expect(try JSONDecoder().decode([ShortcutID: Int].self, from: shortcuts) == [.dimToggle: 9])
    }

    /// A read-only CoreGraphics lookup; an ID macOS does not know gives no key.
    @Test func noKeyForAnUnknownDisplayID() {
        #expect(DisplayKey.of(0xDEAD_BEEF) == nil)
    }

    @Test func monotonicInstantsAddAndSubtract() {
        let a = MonotonicInstant(sinceOrigin: .seconds(2))
        #expect(a + .milliseconds(150) - a == .milliseconds(150) && a < a + .nanoseconds(1))
    }

    @Test func gammaTablesHaveAnIdentityAndAMaximum() {
        let identity = GammaTable.identity(count: 1024)
        #expect(identity.count == 1024 && identity.red.first == 0 && identity.red.last == 1)
        #expect(abs(identity.green[512] - 0.5005) < 0.0001 && identity.maximum == 1)          // display-facts.md §4
        #expect(GammaTable.identity(count: 1).red == [0] && GammaTable.identity(count: 0).maximum == 0)
        let scaled = GammaTable(red: identity.red.map { $0 * 1.2 }, green: identity.green, blue: identity.blue)
        #expect(abs(scaled.maximum - 1.2) < 0.0001)
    }

    @Test func schedulesSpanMidnight() {
        let day = ScheduleWindow(startMinute: 9 * 60, endMinute: 17 * 60)
        #expect(day.contains(minuteOfDay: 9 * 60) && !day.contains(minuteOfDay: 17 * 60) && !day.contains(minuteOfDay: 0))
        let night = ScheduleWindow(startMinute: 22 * 60, endMinute: 6 * 60)
        #expect(night.contains(minuteOfDay: 23 * 60) && night.contains(minuteOfDay: 0) && !night.contains(minuteOfDay: 12 * 60))
        #expect(ScheduleWindow(startMinute: -5, endMinute: 5000) == ScheduleWindow(startMinute: 0, endMinute: 1439))
    }

    @Test func shieldsCoverLockScreensaverSleepAndOtherSessions() {
        let power = PowerState(source: .adapter, batteryPercent: nil, isLowPowerMode: false)
        #expect(!SystemSnapshot(power: power).isShielded)
        #expect(SystemSnapshot(power: power, isScreenLocked: true).isShielded)
        #expect(SystemSnapshot(power: power, isScreensaverRunning: true).isShielded)
        #expect(SystemSnapshot(power: power, areDisplaysAsleep: true).isShielded)
        #expect(SystemSnapshot(power: power, isSystemSleeping: true).isShielded)
        #expect(SystemSnapshot(power: power, isSessionActive: false).isShielded)
        #expect(ThermalLevel.serious < .critical && ThermalLevel.nominal < .fair)
    }

    @Test func boostOnlyAndGlobalReasons() {
        let booster = ConflictingApp(entryID: "x", severity: .booster, bundleID: "com.example.booster", processID: 1,
                                     displayName: "Booster")
        let conditional = ConflictingApp(entryID: "y", severity: .conditional, bundleID: nil, processID: 2, displayName: "Y")
        let boostOnly: [LimitReason] = [.boostNotEnabled, .thermalCritical, .lowPowerMode, .battery(percent: 10, threshold: 20),
                                        .onBattery, .outsideSchedule, .fullScreenVideo, .fullScreenApp,
                                        .pausedApp(bundleID: "com.apple.TV"), .game, .oledIdle]
        #expect(boostOnly.allSatisfy { $0.blocksBoostOnly })
        let stops: [LimitReason] = [.masterOff, .shielded, .conflict(booster), .tripped(.oscillation), .focusOff,
                                    .userPaused(until: Date()), .notSupported(.virtualDisplay), .headroom, .safeLimit]
        #expect(!stops.contains { $0.blocksBoostOnly })
        #expect(LimitReason.conflict(booster).isGlobal && !LimitReason.conflict(conditional).isGlobal)
        #expect(LimitReason.lowPowerMode.isGlobal && !LimitReason.fullScreenVideo.isGlobal && !LimitReason.headroom.isGlobal)
    }

    @Test func verdictsSayWhatTheyAllow() {
        #expect(DisplayVerdict.supported(safeGain: nil, peakGain: 1.94).allowsBoost)
        #expect(DisplayVerdict.presetLimits(presetPeakNits: 600, panelPeakNits: 1600).allowsBoost)
        #expect(!DisplayVerdict.turnOnHDR.allowsBoost && DisplayVerdict.turnOnHDR.allowsDim)
        #expect(!DisplayVerdict.mirrored.allowsBoost && DisplayVerdict.mirrored.allowsDim)
        #expect(!DisplayVerdict.lcdClass.allowsBoost && DisplayVerdict.lcdClass.allowsDim)
        // No backed top: no boost, dimming kept (C-PLATFORM-3; `.checking` there took dimming away).
        #expect(!DisplayVerdict.panelFactsUnknown.allowsBoost && DisplayVerdict.panelFactsUnknown.allowsDim)
        for noDim: DisplayVerdict in [.virtualDisplay, .noGammaTable, .referencePreset, .checking] {
            #expect(!noDim.allowsDim && !noDim.allowsBoost)
        }
        #expect(TriggerPixel.bright.rawComponent == 1.6 && TriggerPixel.black.rawComponent == 0)
        #expect(BoostStatus.initial.symbol == .off && !BoostStatus.initial.isOn && !BoostStatus.initial.isReady)
    }

    /// D17: ⌃⌥⌘ with B, =, -, 0 and 9 (kVK_ANSI positions), no default for Max and Fill Light.
    @Test func shortcutDefaults() {
        let hyper: KeyCombo.Modifiers = [.control, .option, .command]
        let defaults = Dictionary(uniqueKeysWithValues: ShortcutCatalog.all.map { ($0.id, $0.defaultCombo) })
        #expect(ShortcutCatalog.all.count == 7 && defaults.count == 7)
        #expect(defaults[.toggle] == KeyCombo(keyCode: 11, modifiers: hyper))
        #expect(defaults[.brighter] == KeyCombo(keyCode: 24, modifiers: hyper))
        #expect(defaults[.lessBright] == KeyCombo(keyCode: 27, modifiers: hyper))
        #expect(defaults[.standard] == KeyCombo(keyCode: 29, modifiers: hyper))
        #expect(defaults[.dimToggle] == KeyCombo(keyCode: 25, modifiers: hyper))
        #expect(defaults[.max] == .some(nil) && defaults[.fillLight] == .some(nil))
        // Never ⌃⌥⌘8 (28), ⌃⌥⌘, (43), ⌃⌥⌘. (47), ⌃⌥⌘V (9), ⌃⌥⌘D (2), or ⌃⌥Space.
        let codes = ShortcutCatalog.all.compactMap(\.defaultCombo?.keyCode)
        #expect(Set(codes).isDisjoint(with: [28, 43, 47, 9, 2, 49]))
    }

    /// Contract lane (WP0b): `UpdateChecking.repositoryURL` came after WP0a with a default, so existing conformers
    /// (the preview fake) compile unchanged and offer no link.
    @MainActor @Test func updateCheckingHasNoRepositoryPageByDefault() {
        let updates: any UpdateChecking = PreviewUpdateChecking(isConfigured: true)
        #expect(updates.repositoryURL == nil)
    }

    /// Contract lane (WP11): `BoostControl.forgetLearnedMethods()` came after WP0a with a default, so conformers that
    /// learn nothing compile unchanged; the preview control records the call for Settings ▸ Advanced's tests.
    @MainActor @Test func forgetLearnedMethodsReachesTheEngine() {
        let preview = PreviewBoostControl(fixture: .builtinXDRLidOpen)
        let boost: any BoostControl = preview
        boost.forgetLearnedMethods()
        #expect(preview.calls == ["forgetLearnedMethods"])
    }

    @Test func machineIdentityRoundTripsAsJSON() throws {
        let machine = MachineIdentity(model: "Mac16,5", osBuild: "26A434", osMajor: 27, osMinor: 0, osPatch: 1)
        #expect(try JSONDecoder().decode(MachineIdentity.self, from: JSONEncoder().encode(machine)) == machine)
    }
}
