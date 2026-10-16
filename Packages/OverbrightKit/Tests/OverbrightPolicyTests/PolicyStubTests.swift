// OverbrightPolicyTests/PolicyStubTests.swift — the WP0a stubs answer the safe, neutral thing until WP1 lands.
// ARCHITECTURE.md §3.10. WP1 replaces these with the real suites.
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightPolicy

@Suite struct PolicyStubTests {
    @Test func stubsAreNeutral() {
        let facts = DisplayFixture.builtinXDRLidOpen.displays[0].facts
        #expect(GainCeiling.sliderTop(facts: facts, capMode: .safe, isOLED: false) == 1)
        #expect(EligibilityClassifier.classify(facts, preferences: DisplayPreferences(), reading: nil,
                                               machine: DisplayFixture.ownerMachine).verdict == .checking)
        #expect(TableClassifier.classify(.identity(count: 4), expectedBase: .identity(count: 4)) == .matchesBase)
        #expect(BoostPolicy.reduce(PolicyInput(isMasterOn: true, pausedUntil: nil, now: Date(), minuteOfDay: 0,
                                               machine: DisplayFixture.ownerMachine, settings: PolicySettings(),
                                               system: SystemSnapshot(power: PowerState(source: .adapter, batteryPercent: nil,
                                                                                        isLowPowerMode: false)),
                                               displays: [], continuedEntryIDs: [])).displays.isEmpty)
        let app = ConflictMatcher.RunningApp(bundleID: "com.example.booster", executableName: nil, teamID: nil, processID: 1,
                                             localizedName: "Booster")
        #expect(ConflictMatcher.match(app, in: [], ownBundleID: "app.overbright.Overbright") == nil)
    }
}
