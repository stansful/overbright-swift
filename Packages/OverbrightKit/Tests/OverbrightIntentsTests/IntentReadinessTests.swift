// OverbrightIntentsTests/IntentReadinessTests.swift — the router's readiness wait (ARCHITECTURE.md §7.7): an intent
// that arrives before the composition root connected the router, or before the engine is ready, waits at most 5 s on
// the router's time source and then fails with "Overbright is still starting"; once ready it runs, after the launch
// work, so a turn-on from an intent overrides "Launch, keep off". Manual time only (no real-time waits except
// `eventually` for task scheduling).
import Foundation
import OverbrightCore
import OverbrightTestSupport
import Testing
@testable import OverbrightIntents

@MainActor @Suite struct IntentReadinessTests {
    private let time = ManualTimeSource()
    private let fixture = DisplayFixture.builtinXDRLidOpen

    private func notReadyEngine() -> PreviewBoostControl {
        let boost = PreviewBoostControl(fixture: fixture)
        boost.status.isReady = false
        return boost
    }

    private func connect(_ router: IntentRouter, _ boost: PreviewBoostControl) {
        router.connect(boost: boost, displays: FakeDisplayDirectory(fixture: fixture), signals: FakeSystemSignals())
    }

    @Test func anUnconnectedRouterGivesUpAfterFiveSeconds() async {
        let router = IntentRouter(time: time)
        let request = Task { try await router.toggle() }
        #expect(await eventually { time.sleeperCount == 1 })
        #expect(router.wasRequestedBeforeConnection)
        await time.advance(by: .milliseconds(4_900))
        #expect(time.sleeperCount == 1)                          // still waiting
        await time.advance(by: .milliseconds(100))
        await #expect(throws: IntentRouterError.notReady) { try await request.value }
        #expect(!router.isConnected)
    }

    @Test func aRequestBeforeTheConnectionRunsOnceTheEngineIsReady() async throws {
        let router = IntentRouter(time: time)
        let request = Task { try await router.turnOn() }
        #expect(await eventually { time.sleeperCount == 1 })
        let boost = PreviewBoostControl(fixture: fixture)
        connect(router, boost)
        try await request.value
        #expect(boost.calls == ["setOn(true,intent)"])
        #expect(await eventually { time.sleeperCount == 0 })      // the timeout was cancelled
    }

    @Test func aConnectedRouterWaitsForTheEngine() async throws {
        let router = IntentRouter(time: time)
        let boost = notReadyEngine()
        connect(router, boost)
        let request = Task { try await router.toggle() }
        #expect(await eventually { time.sleeperCount == 1 })
        #expect(boost.calls.isEmpty)
        #expect(!router.wasRequestedBeforeConnection)
        boost.status.isReady = true
        try await request.value
        #expect(boost.calls == ["toggle(intent)"])
    }

    @Test func anEngineThatNeverGetsReadyFailsTheIntent() async throws {
        let router = IntentRouter(time: time)
        let boost = notReadyEngine()
        connect(router, boost)
        let request = Task { try await router.setExtraBrightness(.preset(.max), display: nil) }
        #expect(await eventually { time.sleeperCount == 1 })
        await time.advance(by: IntentRouter.readinessTimeout)
        await #expect(throws: IntentRouterError.notReady) { try await request.value }
        #expect(boost.calls.isEmpty)
        boost.status.isReady = true                               // a later request runs at once
        try await router.setExtraBrightness(.preset(.max), display: nil)
        #expect(boost.calls == ["setExtraBrightness(max,all,intent)"])
    }

    @Test func anIntentTurnOnOverridesLaunchKeepOff() async throws {
        let router = IntentRouter(time: time)
        let boost = notReadyEngine()
        connect(router, boost)
        let request = Task { try await router.turnOn() }          // the intent that launched Overbright
        #expect(await eventually { time.sleeperCount == 1 })
        boost.status.isOn = false                                 // launch behaviour "Launch, keep off" applied …
        boost.status.isReady = true                               // … then the launch work ends
        try await request.value
        #expect(boost.status.isOn)
        #expect(boost.calls == ["setOn(true,intent)"])
    }

    @Test func everyWaitingIntentRunsWhenTheEngineGetsReady() async throws {
        let router = IntentRouter(time: time)
        let boost = notReadyEngine()
        connect(router, boost)
        let first = Task { try await router.dim(percent: 50, display: nil) }
        let second = Task { try await router.resume() }
        #expect(await eventually { time.sleeperCount == 2 })
        boost.status.isReady = true
        try await first.value
        try await second.value
        #expect(Set(boost.calls) == ["setDimLight(0.5,all,intent)", "resume(intent)"])
    }

    @Test func aCancelledIntentStopsWaiting() async {
        let router = IntentRouter(time: time)
        let request = Task { try await router.toggle() }
        #expect(await eventually { time.sleeperCount == 1 })
        request.cancel()
        await #expect(throws: IntentRouterError.notReady) { try await request.value }
    }
}
