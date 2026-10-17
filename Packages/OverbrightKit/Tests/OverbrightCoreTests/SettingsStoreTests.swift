// OverbrightCoreTests/SettingsStoreTests.swift — adapted from Cranny's settings tests (the owner's MIT code): persistence,
// reset, namespaces, Undo of Reset All, nested keyed values, per-key observation; plus the defaults of ARCHITECTURE.md
// §3.8 ("Defaults at a glance").
import Foundation
import os
import Testing
@testable import OverbrightCore

@MainActor @Suite struct SettingsStoreTests {
    @Test func settingsPersistResetAndNamespace() throws {
        let defaults = InMemoryDefaults()
        let a = SettingsStore(defaults: defaults)
        #expect(a[AutomationSettings.batteryThreshold] == 20 && a.isDefault(AutomationSettings.batteryThreshold))
        a[AutomationSettings.batteryThreshold] = 35
        #expect(SettingsStore(defaults: defaults)[AutomationSettings.batteryThreshold] == 35)   // persisted as JSON
        #expect(defaults.data(forKey: "overbright.automations.batteryThreshold") != nil)
        a.reset(namespace: .automations)
        #expect(a[AutomationSettings.batteryThreshold] == 20)                                   // live box reset
        #expect(defaults.data(forKey: "overbright.automations.batteryThreshold") == nil)

        let key = DisplayKey(rawValue: "0b21e7f1-0000-4000-8000-000000000001")
        a[DisplaySettings.perDisplay] = [key: DisplayPreferences(boostEnabled: true, capMode: .peak)]
        let json = try #require(defaults.data(forKey: "overbright.displays.perDisplay"))
        #expect(String(decoding: json, as: UTF8.self).contains("\"0B21E7F1-0000-4000-8000-000000000001\""))  // keyed by UUID
        a.resetAll()
        #expect(a[DisplaySettings.perDisplay].isEmpty)
    }

    @Test func settingTheDefaultRemovesTheStoredValue() {
        let defaults = InMemoryDefaults()
        let store = SettingsStore(defaults: defaults)
        store[GeneralSettings.showsHUD] = false
        #expect(defaults.data(forKey: "overbright.general.showsHUD") != nil && !store.isDefault(GeneralSettings.showsHUD))
        store[GeneralSettings.showsHUD] = true
        #expect(defaults.data(forKey: "overbright.general.showsHUD") == nil && store.isDefault(GeneralSettings.showsHUD))
        store[GeneralSettings.showsHUD] = false
        store.reset(GeneralSettings.showsHUD)
        #expect(store[GeneralSettings.showsHUD])
    }

    /// A key's id is built once from its namespace and name; keys are equal and hash alike exactly when their ids are,
    /// whatever their defaults.
    @Test func settingKeysAreIdentifiedByTheirID() {
        let key = SettingKey<Int>(.automations, "batteryThreshold", default: 1)
        #expect(key.id == "automations.batteryThreshold" && key == AutomationSettings.batteryThreshold)
        #expect(key == SettingKey<Int>(.automations, "batteryThreshold", default: 2))
        #expect(key != SettingKey<Int>(.automations, "batteryThresholds", default: 1))
        #expect(Set([key, SettingKey<Int>(.automations, "batteryThreshold", default: 3)]).count == 1)
        #expect(FillLightSettings.width.id == "filllight.width")                                 // "filllight" namespace
    }

    @Test func resetAllCanBeUndone() {
        let defaults = InMemoryDefaults()
        let s = SettingsStore(defaults: defaults)
        s[GeneralSettings.clickAction] = .toggle
        s[FillLightSettings.width] = 64
        let snap = s.snapshot()
        s.resetAll()
        #expect(s[GeneralSettings.clickAction] == .openPanel && s[FillLightSettings.width] == 48)
        s.restore(snap)
        #expect(s[GeneralSettings.clickAction] == .toggle && s[FillLightSettings.width] == 64)
        #expect(SettingsStore(defaults: defaults)[GeneralSettings.clickAction] == .toggle)
    }

    @Test func settingsRoundTripNestedKeyedValues() throws {
        let defaults = InMemoryDefaults()
        let a = SettingsStore(defaults: defaults)
        let combo = KeyCombo(keyCode: 11, modifiers: [.control, .option, .command, .shift])
        a[ShortcutSettings.bindings] = [.toggle: combo, .brighter: nil]                         // nil = explicitly off
        let record = CalibrationRecord(outcome: .encoded, mechanism: .table, mergeFactor: 1.61, estimatedExponent: 2.38,
                                       measuredSDRWhiteNits: nil, headroomAtTest: 2.667, potentialAtTest: 16,
                                       osBuild: "26A434", measuredAt: Date(timeIntervalSinceReferenceDate: 800_000_000))
        let key = DisplayKey(rawValue: "0B21E7F1-0000-4000-8000-000000000002")
        a[DisplaySettings.perDisplay] = [key: DisplayPreferences(level: LevelPosition(-0.4), calibration: record,
                                                                 oled: .oled, lastKnownName: "MPG322UX OLED")]
        a[AutomationSettings.schedule] = ScheduleWindow(startMinute: 22 * 60, endMinute: 6 * 60)
        a[AutomationSettings.pausedUntil] = Date(timeIntervalSinceReferenceDate: 800_003_600)
        a[EngineRecords.boostMarker] = BoostMarker(since: Date(timeIntervalSinceReferenceDate: 1), displays: [key],
                                                   maxFactor: 1.237)
        a[EngineRecords.focusDirective] = .on(level: LevelPreset.sunlight.position)
        let b = SettingsStore(defaults: defaults)                                                // a fresh store reads the JSON
        #expect(b[ShortcutSettings.bindings] == [.toggle: combo, .brighter: nil])
        #expect(b[DisplaySettings.perDisplay][key]?.calibration == record)
        #expect(b[DisplaySettings.perDisplay][key]?.level == LevelPosition(-0.4))
        #expect(b[AutomationSettings.schedule]?.contains(minuteOfDay: 23 * 60) == true)
        #expect(b[AutomationSettings.pausedUntil] == Date(timeIntervalSinceReferenceDate: 800_003_600))
        #expect(b[EngineRecords.boostMarker]?.maxFactor == 1.237)
        #expect(b[EngineRecords.focusDirective] == .on(level: LevelPreset.sunlight.position))
        let bindings = try #require(defaults.data(forKey: "overbright.shortcuts.bindings"))
        #expect(String(decoding: bindings, as: UTF8.self).contains("\"boost.toggle\""))          // keyed by raw id
        defaults.set(Data("garbage".utf8), forKey: "overbright.shortcuts.stepSize")              // undecodable → default
        #expect(SettingsStore(defaults: defaults)[ShortcutSettings.stepSize] == .regular)
    }

    /// Reading a key inside `observe` tracks that key only (one observable box per key).
    @Test func observationIsPerKey() async {
        let store = SettingsStore(defaults: InMemoryDefaults())
        var delivered: [Bool] = []
        let token = observe({ store[DisplaySettings.linkLevels] }, onChange: { delivered.append($0) })
        store[DisplaySettings.lastDimLight] = 0.1                                                // another key
        for _ in 0..<200 { await Task.yield() }
        #expect(delivered.isEmpty)
        store[DisplaySettings.linkLevels] = true
        for _ in 0..<200 where delivered.isEmpty { await Task.yield() }
        #expect(delivered == [true])
        store.resetAll()                                                                         // reloads live boxes
        for _ in 0..<200 where delivered.count < 2 { await Task.yield() }
        #expect(delivered == [true, false])
        token.cancel()
    }

    /// The defaults of §3.8's "Defaults at a glance" and DESIGN.md §7.
    @Test func defaultsMatchTheCatalog() {
        let s = SettingsStore(defaults: InMemoryDefaults())
        #expect(s[GeneralSettings.launchBehavior] == .launchOnly && s[GeneralSettings.showsMenuBarIcon])
        #expect(s[GeneralSettings.clickAction] == .openPanel && s[GeneralSettings.showsHUD] && s[GeneralSettings.haptics])
        #expect(!s[GeneralSettings.showsDockIcon])
        #expect(s[DisplaySettings.perDisplay].isEmpty && !s[DisplaySettings.linkLevels])
        #expect(s[DisplaySettings.linkedLevel] == LevelPosition(0.5) && s[DisplaySettings.lastDimLight] == 0.25)
        #expect(s[DisplaySettings.boostOnlyNearFullBrightness])
        #expect(s[AutomationSettings.batteryGuard] == .belowThreshold && s[AutomationSettings.batteryThreshold] == 20)
        #expect(s[AutomationSettings.pauseInLowPowerMode] && s[AutomationSettings.autoOffMinutes] == nil)
        #expect(s[AutomationSettings.pauseForFullScreenVideo] && !s[AutomationSettings.pauseForAllFullScreen])
        #expect(!s[AutomationSettings.pauseInGames] && s[AutomationSettings.pauseForListedApps])
        #expect(s[AutomationSettings.pausedApps].count == 12 && s[AutomationSettings.pausedApps].allSatisfy(\.isEnabled))
        #expect(s[AutomationSettings.schedule] == nil && s[AutomationSettings.oledIdleMinutes] == 5)
        #expect(s[AutomationSettings.pausedUntil] == nil)
        #expect(s[ShortcutSettings.bindings].isEmpty && s[ShortcutSettings.stepSize] == .regular)
        #expect(s[FillLightSettings.display] == nil && s[FillLightSettings.width] == 48)
        #expect(s[FillLightSettings.warmth] == 0.4 && s[FillLightSettings.brightness] == 0.8)
        #expect(!s[FillLightSettings.autoWithCamera] && s[FillLightSettings.cameraFilter] == .anyCamera)
        #expect(!s[AdvancedSettings.detailedLogging] && s[AdvancedSettings.alwaysContinue].isEmpty)
        #expect(s[OnboardingSettings.completedVersion] == nil && !s[OnboardingSettings.calibrationTipShown])
        #expect(s[OnboardingSettings.hiddenIconNoticeVersion] == nil && s[OnboardingSettings.declinedMoveVersion] == nil)
        #expect(!s[UpdateSettings.automatic] && !s[UpdateSettings.prereleases] && s[UpdateSettings.lastCheck] == nil)
        #expect(s[EngineRecords.boostMarker] == nil && s[EngineRecords.focusDirective] == .leaveAlone)

        let preferences = DisplayPreferences()
        #expect(preferences.boostEnabled == nil && preferences.level == LevelPreset.brightRoom.position)
        #expect(preferences.capMode == .safe && preferences.mechanism == .automatic && preferences.oled == .automatic)
        #expect(preferences.calibration == nil && preferences.triggerOverride == nil && !preferences.oledNoticeAcknowledged)
        #expect(StepSize.regular.stops == 0.25 && abs(StepSize.fine.stops - 1.0 / 12) < 1e-12)
    }

    /// Every key id is unique: two keys sharing an id would overwrite each other's JSON.
    @Test func keyIDsAreUnique() {
        let ids = [GeneralSettings.launchBehavior.id, GeneralSettings.showsMenuBarIcon.id, GeneralSettings.clickAction.id,
                   GeneralSettings.showsHUD.id, GeneralSettings.haptics.id, GeneralSettings.showsDockIcon.id,
                   DisplaySettings.perDisplay.id, DisplaySettings.linkLevels.id, DisplaySettings.linkedLevel.id,
                   DisplaySettings.lastDimLight.id, DisplaySettings.boostOnlyNearFullBrightness.id,
                   AutomationSettings.batteryGuard.id, AutomationSettings.batteryThreshold.id,
                   AutomationSettings.pauseInLowPowerMode.id, AutomationSettings.autoOffMinutes.id,
                   AutomationSettings.pauseForFullScreenVideo.id, AutomationSettings.pauseForAllFullScreen.id,
                   AutomationSettings.pauseInGames.id, AutomationSettings.pauseForListedApps.id,
                   AutomationSettings.pausedApps.id, AutomationSettings.schedule.id, AutomationSettings.oledIdleMinutes.id,
                   AutomationSettings.pausedUntil.id, ShortcutSettings.bindings.id, ShortcutSettings.stepSize.id,
                   FillLightSettings.display.id, FillLightSettings.width.id, FillLightSettings.warmth.id,
                   FillLightSettings.brightness.id, FillLightSettings.autoWithCamera.id, FillLightSettings.cameraFilter.id,
                   AdvancedSettings.detailedLogging.id, AdvancedSettings.alwaysContinue.id,
                   OnboardingSettings.completedVersion.id, OnboardingSettings.calibrationTipShown.id,
                   OnboardingSettings.hiddenIconNoticeVersion.id, OnboardingSettings.declinedMoveVersion.id,
                   UpdateSettings.automatic.id, UpdateSettings.prereleases.id, UpdateSettings.lastCheck.id,
                   EngineRecords.boostMarker.id, EngineRecords.focusDirective.id]
        #expect(Set(ids).count == ids.count)
        #expect(!ids.contains("revision"))                                                       // the upgrade key
    }

    /// Keys of different value types never share a box, and a key read with another value type than its box gets a new
    /// box that loads what is stored, while the first type's box keeps working.
    @Test func keysOfDifferentValueTypesNeverShareABox() {
        let defaults = InMemoryDefaults()
        let store = SettingsStore(defaults: defaults)
        let count = SettingKey<Int>(.advanced, "boxProbeCount", default: 1)
        let flag = SettingKey<Bool>(.advanced, "boxProbeFlag", default: false)
        let words = SettingKey<String>(.advanced, "boxProbeWords", default: "none")
        store[count] = 5
        store[flag] = true
        store[words] = "some"
        #expect(store[count] == 5 && store[flag] && store[words] == "some")
        store[count] = 6
        #expect(store[count] == 6 && store[flag] && store[words] == "some")

        // One id, two value types: the second type's box starts from what is stored (undecodable as a String: the
        // default), the first type then gets a box of its own again, loaded from defaults.
        let sameIDAsText = SettingKey<String>(.advanced, "boxProbeCount", default: "text")
        #expect(store[sameIDAsText] == "text")
        #expect(store[count] == 6)
        store[count] = 7
        #expect(SettingsStore(defaults: defaults)[count] == 7)
    }

    /// The hand-written observation of a box (its key path made once) keeps per-key granularity: a write invalidates
    /// only readers of that key; writing the value it already holds invalidates nobody, as with `@Observable`.
    @Test func aBoxObservesOnlyItsKey() async {
        let store = SettingsStore(defaults: InMemoryDefaults())
        var fired = 0
        let token = observe({ store[GeneralSettings.showsHUD] }, onChange: { _ in fired += 1 })
        store[GeneralSettings.haptics] = !store[GeneralSettings.haptics]
        for _ in 0..<10 { await Task.yield() }
        #expect(fired == 0)
        store[GeneralSettings.showsHUD] = !store[GeneralSettings.showsHUD]
        for _ in 0..<10 { await Task.yield() }
        #expect(fired == 1)
        token.cancel()

        let box = SettingBox(3)
        let changes = OSAllocatedUnfairLock(initialState: 0)
        withObservationTracking { _ = box.value } onChange: { changes.withLock { $0 += 1 } }
        box.value = 3
        #expect(changes.withLock { $0 } == 0)
        box.value = 4
        #expect(changes.withLock { $0 } == 1 && box.value == 4)
    }

    /// `setDeferringWrite`: every reader sees the value at once; `defaults` gets it only at `writeDeferred()` (once,
    /// with the value as it is then); a plain write settles what was owed; a reset drops it.
    @Test func deferredWritesReachDefaultsOnlyWhenWritten() {
        let defaults = InMemoryDefaults()
        let store = SettingsStore(defaults: defaults)
        let key = "overbright.displays.linkedLevel"
        for step in [0.3, 0.4, 0.5] {
            store.setDeferringWrite(DisplaySettings.linkedLevel, LevelPosition(step))
            #expect(store[DisplaySettings.linkedLevel] == LevelPosition(step))
        }
        #expect(defaults.data(forKey: key) == nil && store.hasDeferredWrites)
        store.writeDeferred()
        #expect(SettingsStore(defaults: defaults)[DisplaySettings.linkedLevel] == LevelPosition(0.5))
        #expect(!store.hasDeferredWrites)

        store.setDeferringWrite(DisplaySettings.linkedLevel, LevelPosition(0.6))
        store[DisplaySettings.linkedLevel] = LevelPosition(0.7)                                // a plain write
        #expect(!store.hasDeferredWrites)
        #expect(SettingsStore(defaults: defaults)[DisplaySettings.linkedLevel] == LevelPosition(0.7))

        store.setDeferringWrite(DisplaySettings.linkedLevel, LevelPosition(0.8))
        store.reset(namespace: .displays)
        #expect(!store.hasDeferredWrites && defaults.data(forKey: key) == nil)
        #expect(store[DisplaySettings.linkedLevel] == DisplaySettings.linkedLevel.defaultValue)
    }

    /// A deferred value still notifies its key's observers at once.
    @Test func aDeferredWriteObservesAtOnce() async {
        let store = SettingsStore(defaults: InMemoryDefaults())
        var seen: [LevelPosition] = []
        let token = observe({ store[DisplaySettings.linkedLevel] }, onChange: { seen.append($0) })
        store.setDeferringWrite(DisplaySettings.linkedLevel, LevelPosition(0.45))
        for _ in 0..<10 { await Task.yield() }
        #expect(seen == [LevelPosition(0.45)])
        token.cancel()
    }
}
