// OverbrightIntentsTests/IntentRouterTests.swift — the router seam (ARCHITECTURE.md §7.7, §10.0): no-argument init,
// `connect(boost:displays:signals:)`, one method per intent against `PreviewBoostControl`, the Focus sink. WP8 adds the
// readiness wait with its timeout and the launch-policy override (`IntentRouterTests` grows there).
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightIntents

@MainActor @Suite struct IntentRouterTests {
    private let fixture = DisplayFixture.builtinXDRLidOpen

    @Test func anUnconnectedRouterIsNotReady() async {
        let router = IntentRouter()
        #expect(!router.isConnected)
        await #expect(throws: IntentRouterError.notReady) { try await router.toggle() }
    }

    @Test func everyIntentReachesTheEngine() async throws {
        let router = IntentRouter()
        let boost = PreviewBoostControl(fixture: fixture)
        let signals = FakeSystemSignals()
        router.connect(boost: boost, displays: FakeDisplayDirectory(fixture: fixture), signals: signals)
        let display = try #require(fixture.displays.first?.key)
        try await router.toggle()
        try await router.turnOn()
        try await router.turnOff()
        try await router.setExtraBrightness(.preset(.sunlight), display: display)
        try await router.dim(percent: 1, display: nil)
        try await router.pause(for: .seconds(60))
        try await router.resume()
        try await router.returnToStandard()
        #expect(try await router.state().isOn == false)
        #expect(boost.calls == ["toggle(intent)", "setOn(true,intent)", "setOn(false,intent)",
                                "setExtraBrightness(sunlight,\(display.rawValue),intent)", "setDimLight(0.02,all,intent)",
                                boost.calls[5], "resume(intent)", "returnToStandard(intent)"])
        #expect(boost.calls[5].hasPrefix("pause("))
        await #expect(throws: IntentRouterError.displayNotConnected) {
            try await router.setExtraBrightness(.multiplier(1.3), display: DisplayKey(rawValue: "0B21E7F1-FFFF"))
        }
    }

    @Test func aFocusDirectiveBeforeTheConnectionIsDelivered() {
        let router = IntentRouter()
        let signals = FakeSystemSignals()
        router.focus(.off)
        #expect(signals.focusDirectives.isEmpty)
        router.connect(boost: PreviewBoostControl(fixture: fixture), displays: FakeDisplayDirectory(fixture: fixture),
                       signals: signals)
        router.focus(.on(level: LevelPreset.max.position))
        #expect(signals.focusDirectives == [.off, .on(level: LevelPreset.max.position)])
    }

    @Test func thePublisherSeamBuilds() {
        let publisher = ControlStatePublisher(boost: PreviewBoostControl(fixture: fixture))
        publisher.start()
        publisher.stop()
    }
}
