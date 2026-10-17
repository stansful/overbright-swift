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
        try await router.setOn(true)                                   // the Control Center toggle
        #expect(boost.calls == ["toggle(intent)", "setOn(true,intent)", "setOn(false,intent)",
                                "setExtraBrightness(sunlight,\(display.rawValue),intent)", "setExtraBrightness(×1.3,all,intent)",
                                "setDimLight(0.25,\(display.rawValue),intent)",
                                "pause(\(time.wallClock.addingTimeInterval(60).timeIntervalSinceReferenceDate),intent)",
                                "resume(intent)", "returnToStandard(intent)", "setOn(true,intent)"])
        #expect(try await router.state().isOn == true)
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

    /// A crafted shortcut can pass any number of seconds (§9.2 rule 2: no trap): an infinite or huge pause is the
    /// longest one (24 h), not a number is the default hour, a negative one is none. `Duration.seconds(Double)` traps on
    /// all but the last, so the adapter hands the router the plain number.
    @Test func everyPauseLengthIsSafe() async throws {
        let (router, boost, _) = connected()
        let now = time.wallClock
        for seconds in [Double.infinity, 1e30, .nan, -.infinity, -5, 90, .greatestFiniteMagnitude] {
            try await router.pause(forSeconds: seconds)
        }
        try await router.pause(for: .seconds(Int64.max))
        let day = now.addingTimeInterval(IntentRouter.longestPause).timeIntervalSinceReferenceDate
        let hour = now.addingTimeInterval(IntentRouter.fallbackPause).timeIntervalSinceReferenceDate
        let none = now.timeIntervalSinceReferenceDate
        let ninety = now.addingTimeInterval(90).timeIntervalSinceReferenceDate
        #expect(boost.calls == [day, day, hour, none, none, ninety, day, day].map { "pause(\($0),intent)" })
        #expect(IntentRouter.longestPause == 86_400 && IntentRouter.fallbackPause == 3_600)
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

    /// Every launch reads the Focus filter: that read is not a request, so it never marks an ordinary cold launch as
    /// one made for an intent (the shell's launch UI, ARCHITECTURE.md §7.6). A Focus delivery and an intent are.
    @Test func theLaunchReadIsNotARequestButIntentsAndFocusDeliveriesAre() async throws {
        let router = IntentRouter(time: ManualTimeSource())
        await router.applyLaunchFocus { .leaveAlone }
        #expect(!router.wasRequestedBeforeConnection)
        #expect(router.requestCount == 0)
        router.focus(.off)
        #expect(router.wasRequestedBeforeConnection)
        #expect(router.requestCount == 1)
        let (connectedRouter, _, _) = connected()
        await connectedRouter.applyLaunchFocus { .off }
        #expect(connectedRouter.requestCount == 0)
        try await connectedRouter.turnOn()
        try await connectedRouter.returnToStandard()
        #expect(connectedRouter.requestCount == 2)
        #expect(!connectedRouter.wasRequestedBeforeConnection)
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
