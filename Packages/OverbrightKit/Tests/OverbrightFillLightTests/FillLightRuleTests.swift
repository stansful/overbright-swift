// OverbrightFillLightTests/FillLightRuleTests.swift — the camera rule: on 1 s after a camera starts, off 3 s after it
// stops, manual Off wins until the camera stops (ARCHITECTURE.md §10.9; DESIGN.md §11). The pure state machine first,
// then the same rule through the controller on a manual clock.
import OverbrightCore
import Testing
@testable import OverbrightFillLight

private func at(_ seconds: Double) -> MonotonicInstant {
    MonotonicInstant(sinceOrigin: .milliseconds(Int64((seconds * 1_000).rounded())))
}

/// A rule that follows the camera, with the standard 1 s / 3 s timing.
private func followingRule() -> FillLightRule {
    var rule = FillLightRule()
    rule.setFollowsCamera(true, now: at(0))
    return rule
}

@Suite struct FillLightRuleTests {
    @Test func cameraTurnsTheLightOnOneSecondAfterItStarts() {
        var rule = followingRule()
        rule.cameraChanged(running: true, now: at(10))
        #expect(rule.nextDeadline == at(11))
        rule.advance(to: at(10.99))
        #expect(!rule.isOn)
        rule.advance(to: at(11))
        #expect(rule.isOn && rule.isAutomatic && rule.isCameraSessionActive)
        #expect(rule.nextDeadline == nil)
    }

    @Test func lightGoesOffThreeSecondsAfterTheCameraStops() {
        var rule = followingRule()
        rule.cameraChanged(running: true, now: at(0))
        rule.advance(to: at(1))
        rule.cameraChanged(running: false, now: at(20))
        #expect(rule.nextDeadline == at(23))
        rule.advance(to: at(22.99))
        #expect(rule.isOn)
        rule.advance(to: at(23))
        #expect(!rule.isOn && !rule.isAutomatic && !rule.isCameraSessionActive)
    }

    @Test func cameraBackWithinTheOffDelayKeepsTheLightOn() {
        var rule = followingRule()
        rule.cameraChanged(running: true, now: at(0))
        rule.advance(to: at(1))
        rule.cameraChanged(running: false, now: at(10))   // switching cameras in a call
        rule.cameraChanged(running: true, now: at(11))
        #expect(rule.nextDeadline == nil)
        rule.advance(to: at(30))
        #expect(rule.isOn && rule.isAutomatic)
        rule.cameraChanged(running: false, now: at(40))
        rule.advance(to: at(43))
        #expect(!rule.isOn)
    }

    @Test func aCameraBlinkShorterThanTheOnDelayDoesNothing() {
        var rule = followingRule()
        rule.cameraChanged(running: true, now: at(0))
        rule.cameraChanged(running: false, now: at(0.5))
        #expect(rule.nextDeadline == nil)
        rule.advance(to: at(5))
        #expect(!rule.isOn && !rule.isCameraSessionActive)
    }

    @Test func manualOffWinsUntilTheCameraStops() {
        var rule = followingRule()
        rule.cameraChanged(running: true, now: at(0))
        rule.advance(to: at(1))
        rule.setManually(false)
        #expect(!rule.isOn && rule.isSuppressed)
        // A camera switch inside the call does not bring it back.
        rule.cameraChanged(running: false, now: at(5))
        rule.cameraChanged(running: true, now: at(6))
        rule.advance(to: at(20))
        #expect(!rule.isOn && rule.isSuppressed)
        // The call ends: the suppression ends with it, and the next call turns the light on again.
        rule.cameraChanged(running: false, now: at(30))
        rule.advance(to: at(33))
        #expect(!rule.isSuppressed && !rule.isCameraSessionActive)
        rule.cameraChanged(running: true, now: at(40))
        rule.advance(to: at(41))
        #expect(rule.isOn && rule.isAutomatic)
    }

    @Test func manualOffBeforeTheOnDelayAlsoWins() {
        var rule = followingRule()
        rule.cameraChanged(running: true, now: at(0))
        rule.setManually(false)
        #expect(rule.isSuppressed)
        rule.advance(to: at(1))
        #expect(!rule.isOn && rule.isCameraSessionActive)
    }

    @Test func manualOffWithoutACameraSuppressesNothing() {
        var rule = followingRule()
        rule.setManually(true)
        rule.setManually(false)
        #expect(!rule.isSuppressed)
        rule.cameraChanged(running: true, now: at(0))
        rule.advance(to: at(1))
        #expect(rule.isOn && rule.isAutomatic)
    }

    @Test func aLightTheUserTurnedOnStaysOnAfterTheCall() {
        var rule = followingRule()
        rule.setManually(true)
        rule.cameraChanged(running: true, now: at(1))
        rule.advance(to: at(2))
        #expect(rule.isOn && !rule.isAutomatic)
        rule.cameraChanged(running: false, now: at(5))
        rule.advance(to: at(8))
        #expect(rule.isOn && !rule.isAutomatic)
    }

    @Test func turningItBackOnDuringTheCallMakesItTheUsers() {
        var rule = followingRule()
        rule.cameraChanged(running: true, now: at(0))
        rule.advance(to: at(1))
        rule.setManually(false)
        rule.setManually(true)
        #expect(rule.isOn && !rule.isAutomatic && !rule.isSuppressed)
        rule.cameraChanged(running: false, now: at(10))
        rule.advance(to: at(13))
        #expect(rule.isOn)
    }

    @Test func withTheRuleOffTheCameraDoesNothing() {
        var rule = FillLightRule()
        rule.cameraChanged(running: true, now: at(0))
        #expect(rule.nextDeadline == nil)
        rule.advance(to: at(10))
        #expect(!rule.isOn)
        rule.setManually(true)
        rule.cameraChanged(running: false, now: at(11))
        rule.advance(to: at(20))
        #expect(rule.isOn)
    }

    @Test func turningTheRuleOnWhileACameraRunsCountsAsAStart() {
        var rule = FillLightRule()
        rule.cameraChanged(running: true, now: at(0))
        rule.setFollowsCamera(true, now: at(5))
        #expect(rule.nextDeadline == at(6))
        rule.advance(to: at(6))
        #expect(rule.isOn && rule.isAutomatic)
    }

    @Test func turningTheRuleOffKeepsTheLightAsTheUsers() {
        var rule = followingRule()
        rule.cameraChanged(running: true, now: at(0))
        rule.advance(to: at(1))
        rule.setFollowsCamera(false, now: at(2))
        #expect(rule.isOn && !rule.isAutomatic && rule.nextDeadline == nil)
        rule.cameraChanged(running: false, now: at(3))
        rule.advance(to: at(10))
        #expect(rule.isOn)
    }

    @Test func turningTheRuleOffCancelsAPendingStart() {
        var rule = followingRule()
        rule.cameraChanged(running: true, now: at(0))
        rule.setFollowsCamera(false, now: at(0.5))
        #expect(rule.nextDeadline == nil)
        rule.advance(to: at(2))
        #expect(!rule.isOn)
    }

    @Test func zeroDelaysActAtOnce() {
        var rule = FillLightRule(timing: FillLightRule.Timing(onDelay: .zero, offDelay: .zero))
        rule.setFollowsCamera(true, now: at(0))
        rule.cameraChanged(running: true, now: at(3))
        #expect(rule.nextDeadline == at(3))
        rule.advance(to: at(3))
        #expect(rule.isOn)
        rule.cameraChanged(running: false, now: at(4))
        rule.advance(to: at(4))
        #expect(!rule.isOn)
    }

    @Test func standardTimingIsOneSecondOnThreeSecondsOff() {
        #expect(FillLightRule.Timing.standard.onDelay == .seconds(1))
        #expect(FillLightRule.Timing.standard.offDelay == .seconds(3))
    }
}

/// The same rule through `FillLightController`, the camera signal from `FakeSystemSignals` and a manual clock.
@MainActor @Suite struct FillLightCameraRuleControllerTests {
    private func cameraHarness(rule on: Bool = true) async -> FillLightHarness {
        let harness = FillLightHarness()
        harness.settings[FillLightSettings.autoWithCamera] = on
        await harness.start()
        return harness
    }

    private func camera(_ running: Bool, _ harness: FillLightHarness) async {
        harness.signals.snapshot.isCameraInUse = running
        await harness.settle()
    }

    @Test func cameraOnAndOffDrivesTheFrame() async {
        let h = await cameraHarness()
        await camera(true, h)
        await h.advance(.milliseconds(900))
        #expect(!h.controller.isOn && h.factory.made.isEmpty)
        await h.advance(.milliseconds(100))
        #expect(h.controller.isOn && h.controller.isAutomatic)
        #expect(h.factory.current?.isShown == true)

        await camera(false, h)
        await h.advance(.milliseconds(2_900))
        #expect(h.controller.isOn)
        await h.advance(.milliseconds(100))
        #expect(!h.controller.isOn && !h.controller.isAutomatic)
        #expect(h.factory.live.isEmpty)
    }

    @Test func manualOffDuringACallHoldsUntilTheCameraStops() async {
        let h = await cameraHarness()
        await camera(true, h)
        await h.advance(.seconds(1))
        h.controller.setOn(false, source: .panel)
        #expect(!h.controller.isOn && h.factory.live.isEmpty)
        await h.advance(.seconds(30))
        #expect(!h.controller.isOn)
        await camera(false, h)
        await h.advance(.seconds(3))
        await camera(true, h)
        await h.advance(.seconds(1))
        #expect(h.controller.isOn && h.controller.isAutomatic)
    }

    @Test func withTheRuleOffTheCameraStartsNoTimer() async {
        let h = await cameraHarness(rule: false)
        await camera(true, h)
        #expect(h.time.sleeperCount == 0)
        await h.advance(.seconds(5))
        #expect(!h.controller.isOn && h.factory.made.isEmpty)
    }

    @Test func aCameraAlreadyRunningAtStartTurnsTheLightOn() async {
        let h = FillLightHarness()
        h.settings[FillLightSettings.autoWithCamera] = true
        h.signals.snapshot.isCameraInUse = true
        await h.start()
        await h.advance(.seconds(1))
        #expect(h.controller.isOn && h.controller.isAutomatic)
    }

    @Test func turningTheRuleOnInSettingsDuringACall() async {
        let h = await cameraHarness(rule: false)
        await camera(true, h)
        h.settings[FillLightSettings.autoWithCamera] = true
        await h.settle()
        await h.advance(.seconds(1))
        #expect(h.controller.isOn && h.controller.isAutomatic)
    }

    @Test func byDefaultTheDebouncedSignalActsAtOnce() async {
        // Signals debounces `isCameraInUse` 1 s on / 3 s off (§7.1); the controller adds no second delay.
        let h = FillLightHarness(timing: nil)
        h.settings[FillLightSettings.autoWithCamera] = true
        await h.start()
        await camera(true, h)
        #expect(h.controller.isOn && h.controller.isAutomatic)
        #expect(h.factory.current?.isShown == true)
        await camera(false, h)
        #expect(!h.controller.isOn && h.factory.live.isEmpty)
        #expect(h.time.sleeperCount == 0)                       // no rule deadline, and the settle reads went with it
        await camera(true, h)
        h.controller.setOn(false, source: .panel)                // manual Off wins until the camera stops
        await h.advance(.seconds(30))
        #expect(!h.controller.isOn)
        await camera(false, h)
        await camera(true, h)
        #expect(h.controller.isOn && h.controller.isAutomatic)
    }

    @Test func automaticChangesAreAnnouncedAsAlerts() async {
        let h = await cameraHarness()
        await camera(true, h)
        await h.advance(.seconds(1))
        #expect(h.announcements.texts == ["Fill Light on"])
        #expect(h.journal.snapshot().last { $0.code == "fillLight.on" }?.values["automatic"] == 1)
    }
}
