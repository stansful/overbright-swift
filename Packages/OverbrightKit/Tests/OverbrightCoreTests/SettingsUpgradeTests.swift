// OverbrightCoreTests/SettingsUpgradeTests.swift — adapted from Cranny's SettingsUpgradeTests (the owner's MIT code).
// Overbright starts at settings revision 0 (ARCHITECTURE.md §3.8, §8.2): the mechanism is there, with no steps yet.
import Foundation
import Testing
@testable import OverbrightCore

@MainActor @Suite struct SettingsUpgradeTests {
    @Test func theFirstReleaseIsRevisionZero() {
        #expect(SettingsStore.currentRevision == 0)
        #expect(SettingsStore.revisionKey == "overbright.revision")
    }

    @Test func aFreshInstallRecordsTodaysRevisionAndWritesNothingElse() {
        let defaults = InMemoryDefaults()
        let store = SettingsStore(defaults: defaults)
        #expect(store.storedRevision == nil)
        store.upgradeStoredSettings()
        #expect(store.storedRevision == SettingsStore.currentRevision)       // later launches are not "old" either
        #expect(defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(SettingsStore.keyPrefix) }
                == ["overbright.revision"])
        store.upgradeStoredSettings()                                         // idempotent
        #expect(store.storedRevision == SettingsStore.currentRevision)
    }

    @Test func anInstallWithStoredSettingsKeepsWhatItStored() {
        let defaults = InMemoryDefaults()
        let old = SettingsStore(defaults: defaults)
        old[OnboardingSettings.completedVersion] = "0.1.0"                    // an install from before revisions
        old[AutomationSettings.batteryThreshold] = 35
        let store = SettingsStore(defaults: defaults)
        store.upgradeStoredSettings()
        #expect(store.storedRevision == SettingsStore.currentRevision)
        #expect(store[OnboardingSettings.completedVersion] == "0.1.0" && store[AutomationSettings.batteryThreshold] == 35)
    }

    /// Reset All returns to today's defaults, and neither it nor its Undo makes the install look old again.
    @Test func resetAllAndItsUndoKeepTheRevision() {
        let defaults = InMemoryDefaults()
        let store = SettingsStore(defaults: defaults)
        store[GeneralSettings.showsHUD] = false
        store.upgradeStoredSettings()
        let snapshot = store.snapshot()
        store.resetAll()
        #expect(store[GeneralSettings.showsHUD] && store.storedRevision == SettingsStore.currentRevision)
        store[GeneralSettings.clickAction] = .toggle                           // something stored again
        store.upgradeStoredSettings()                                          // the next launch
        store.restore(snapshot)
        #expect(!store[GeneralSettings.showsHUD] && store.storedRevision == SettingsStore.currentRevision)
        #expect(store[GeneralSettings.clickAction] == .openPanel)              // the snapshot did not hold it
    }

    /// Launch arguments that seed settings (QA) are not a stored install.
    @Test func onlyStoredKeysMakeAnInstallOld() {
        let defaults = InMemoryDefaults()
        defaults.register(defaults: ["AppleLanguages": ["ru"], "NSSomeAppKitState": true])   // not Overbright keys
        let store = SettingsStore(defaults: defaults)
        store.upgradeStoredSettings()
        #expect(store.storedRevision == SettingsStore.currentRevision)
    }
}
