// OverbrightIntentsTests/IntentRouterTests.swift — the router (ARCHITECTURE.md §7.7, §10.10; DESIGN.md §12.8): each
// intent against `PreviewBoostControl` in canonical units, the per-display checks and their errors, the Focus sink
// with its launch-time read, and the `overbright://control` hand-off with its token. The readiness wait has its own
// suite (`IntentReadinessTests`).
import Foundation
import OverbrightCore
import OverbrightTestSupport
import Testing
@testable import OverbrightIntents

@MainActor @Suite struct IntentRouterTests {
    private let time = ManualTimeSource()

    /// A connected router over `fixture`, ready.
    private func connected(_ fixture: DisplayFixture = .builtinXDRLidOpen)
        -> (IntentRouter, PreviewBoostControl, FakeSystemSignals) {
        let router = IntentRouter(time: time)
        let boost = PreviewBoostControl(fixture: fixture)
        let signals = FakeSystemSignals()
        router.connect(boost: boost, displays: FakeDisplayDirectory(fixture: fixture), signals: signals)
        return (router, boost, signals)
    }

    @Test func everyIntentReachesTheEngineInCanonicalUnits() async throws {
        let (router, boost, _) = connected()
        let display = DisplayFixture.Keys.builtIn
        try await router.toggle()
        try await router.turnOn()
        try await router.turnOff()
        try await router.setExtraBrightness(.preset(.sunlight), display: display)
        try await router.setExtraBrightness(.multiplier(1.3), display: nil)
        try await router.dim(percent: 25, display: display)
        try await router.pause(for: .seconds(60))
        try await router.resume()
        try await router.returnToStandard()
        #expect(boost.calls == ["toggle(intent)", "setOn(true,intent)", "setOn(false,intent)",
                                "setExtraBrightness(sunlight,\(display.rawValue),intent)", "setExtraBrightness(×1.3,all,intent)",
                                "setDimLight(0.25,\(display.rawValue),intent)",
                                "pause(\(time.wallClock.addingTimeInterval(60).timeIntervalSinceReferenceDate),intent)",
                                "resume(intent)", "returnToStandard(intent)"])
        #expect(try await router.state().isOn == false)
    }

    @Test func valuesOutsideTheirRangeAreClamped() async throws {
        let (router, boost, _) = connected()
        try await router.dim(percent: 1, display: nil)
        try await router.dim(percent: 150, display: nil)
        try await router.setExtraBrightness(.multiplier(0.5), display: nil)
        try await router.setExtraBrightness(.multiplier(.nan), display: nil)
        try await router.pause(for: .seconds(-5))
        #expect(boost.calls == ["setDimLight(0.02,all,intent)", "setDimLight(0.99,all,intent)",
                                "setExtraBrightness(×1.0,all,intent)", "setExtraBrightness(×1.0,all,intent)",
                                "pause(\(time.wallClock.timeIntervalSinceReferenceDate),intent)"])
    }

    @Test func aDisplayThatIsNotConnectedIsAnError() async {
        let (router, boost, _) = connected()
        let gone = DisplayKey(rawValue: "0B21E7F1-FFFF-4000-8000-0000000000FF")
        await #expect(throws: IntentRouterError.displayNotConnected) {
            try await router.setExtraBrightness(.multiplier(1.3), display: gone)
        }
        await #expect(throws: IntentRouterError.displayNotConnected) { try await router.dim(percent: 50, display: gone) }
        #expect(boost.calls.isEmpty)
    }

    @Test func eachDisplaysVerdictDecidesWhatItCanDo() async throws {
        let (router, boost, _) = connected(.sidecar)
        boost.decide(DisplayFixture.Keys.builtIn, verdict: supported)
        boost.decide(DisplayFixture.Keys.sidecar, verdict: .virtualDisplay)
        await #expect(throws: IntentRouterError.cannotBoost) {
            try await router.setExtraBrightness(.preset(.max), display: DisplayFixture.Keys.sidecar)
        }
        await #expect(throws: IntentRouterError.cannotDim) {
            try await router.dim(percent: 50, display: DisplayFixture.Keys.sidecar)
        }
        #expect(boost.calls.isEmpty)
        try await router.setExtraBrightness(.preset(.max), display: nil)          // the built-in can
        try await router.dim(percent: 50, display: DisplayFixture.Keys.builtIn)
        #expect(boost.calls.count == 2)
    }

    @Test func everyDisplayFailsOnlyWhenNoneCan() async throws {
        let (router, boost, _) = connected(.mpg322uxHDROff)
        boost.decide(DisplayFixture.Keys.mpg322ux, verdict: .turnOnHDR)
        await #expect(throws: IntentRouterError.cannotBoost) { try await router.setExtraBrightness(.preset(.indoor), display: nil) }
        try await router.dim(percent: 40, display: nil)                            // HDR off still dims
        #expect(boost.calls == ["setDimLight(0.4,all,intent)"])
    }

    @Test func aVerdictNotKnownYetLeavesTheDecisionToTheEngine() async throws {
        let (router, boost, _) = connected(.mpg322uxHDROff)
        try await router.setExtraBrightness(.preset(.indoor), display: DisplayFixture.Keys.mpg322ux)   // no decision yet
        boost.decide(DisplayFixture.Keys.mpg322ux, verdict: .checking)
        try await router.setExtraBrightness(.preset(.indoor), display: nil)
        #expect(boost.calls.count == 2)
    }

    @Test func errorsSayTheSentencesOfTheDesign() {
        #expect(IntentRouterError.notReady.localizedDescription == "Overbright is still starting. Try again in a moment.")
        #expect(IntentRouterError.displayNotConnected.localizedDescription == "That display isn’t connected.")
        #expect(IntentRouterError.cannotBoost.localizedDescription == "This display can’t show extra brightness.")
        #expect(IntentRouterError.cannotDim.localizedDescription == "This display can’t be dimmed.")
        #expect(String(localized: IntentRouterError.cannotDim.localizedStringResource) == "This display can’t be dimmed.")
    }

    // MARK: Focus

    @Test func aFocusDirectiveBeforeTheConnectionIsDelivered() {
        let router = IntentRouter(time: time)
        let signals = FakeSystemSignals()
        router.focus(.off)
        #expect(signals.focusDirectives.isEmpty)
        #expect(router.wasRequestedBeforeConnection)
        router.connect(boost: PreviewBoostControl(fixture: .builtinXDRLidOpen),
                       displays: FakeDisplayDirectory(fixture: .builtinXDRLidOpen), signals: signals)
        router.focus(.on(level: LevelPreset.max.position))
        #expect(signals.focusDirectives == [.off, .on(level: LevelPreset.max.position)])
    }

    @Test func theLaunchReadOfTheFocusFilterIsDelivered() async {
        let (router, _, signals) = connected()
        await router.applyLaunchFocus { .on(level: LevelPreset.sunlight.position) }
        #expect(signals.focusDirectives == [.on(level: LevelPreset.sunlight.position)])
    }

    @Test func aFocusChangeDuringTheLaunchReadWins() async {
        let (router, _, signals) = connected()
        await router.applyLaunchFocus {
            router.focus(.off)                 // the filter performs while `.current` is being read
            return .leaveAlone
        }
        #expect(signals.focusDirectives == [.off])
    }

    @Test func aFailedLaunchReadKeepsThePersistedDirective() async {
        struct Unreadable: Error {}
        let (router, _, signals) = connected()
        await router.applyLaunchFocus { throw Unreadable() }
        #expect(signals.focusDirectives.isEmpty)
    }

    // MARK: overbright://control

    @Test func theControlRouteTurnsOffAlwaysAndOnOnlyWithTheToken() async throws {
        let (router, boost, _) = connected()
        let token = String(repeating: "0f", count: 32)
        router.expectedControlToken = { token }
        #expect(try await router.control(on: false, token: nil))
        #expect(try await !router.control(on: true, token: nil))
        #expect(try await !router.control(on: true, token: String(repeating: "f0", count: 32)))
        #expect(boost.calls == ["setOn(false,intent)"])
        #expect(try await router.control(on: true, token: token))
        #expect(boost.calls == ["setOn(false,intent)", "setOn(true,intent)"])
        router.expectedControlToken = { nil }                                       // the app never made one
        #expect(try await !router.control(on: true, token: token))
        #expect(boost.calls.count == 2)
    }
}
