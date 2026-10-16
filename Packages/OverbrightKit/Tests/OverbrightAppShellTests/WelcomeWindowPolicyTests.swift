// OverbrightAppShellTests/WelcomeWindowPolicyTests.swift — the Welcome window controller's decisions and window
// (ARCHITECTURE.md §7.6; DESIGN.md §8): step names, visual QA, activation hand-back, and the window built by
// `preparedWindow(at:)` (never ordered in): 640 × 480, the requested step, and its close button counting as Skip.
// Ported from Cranny's WelcomeWindowPolicyTests (the owner's MIT code).
import AppKit
import Foundation
import OverbrightCore
import OverbrightOnboarding
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct WelcomeWindowPolicyTests {
    @Test func stepNamesMapToStepsAndUnknownStartsAtStepOne() {
        #expect(WelcomeWindowPolicy.step(named: nil) == .hello)
        #expect(WelcomeWindowPolicy.step(named: "findIt") == .findIt)
        #expect(WelcomeWindowPolicy.step(named: "sideways") == .hello)
    }

    /// Only a scripted Welcome capture is visual QA; an ordinary `make run` (simulated ports, its own suite) records
    /// like a real launch.
    @Test func onlyAWelcomeCaptureIsVisualQA() {
        #expect(WelcomeWindowPolicy.isVisualQA(LaunchArguments(["Overbright", "--qa-welcome", "defaults"])))
        #expect(!WelcomeWindowPolicy.isVisualQA(LaunchArguments(["Overbright", "--off", "--qa-simulate",
                                                                  "--qa-defaults-suite", "app.overbright.Overbright.dev"])))
    }

    @Test func activationGoesBackOnlyWhileOverbrightIsActive() {
        #expect(WelcomeWindowPolicy.handsBackActivation(isActive: true, previousAppIsRunning: true))
        #expect(!WelcomeWindowPolicy.handsBackActivation(isActive: false, previousAppIsRunning: true))  // never steal focus
        #expect(!WelcomeWindowPolicy.handsBackActivation(isActive: true, previousAppIsRunning: false))
    }

    /// The window: 640 × 480, hidden title bar, not resizable, at the step asked for; the close button is Skip, which
    /// applies the login-item default and records that Welcome is finished; a second show reuses nothing closed.
    @Test func theCloseButtonCountsAsSkip() async throws {
        _ = NSApplication.shared
        let services = OverbrightServices.preview()
        let app = PreviewAppControl()
        services.app = app
        let controller = WelcomeWindowController(services: services, arguments: LaunchArguments(["Overbright"]))
        let window = controller.preparedWindow(at: "defaults")
        #expect(window.frame.size == WelcomeView.windowSize)
        #expect(!window.styleMask.contains(.resizable) && window.titleVisibility == .hidden)
        #expect(controller.session?.step == .defaults)
        #expect(controller.preparedWindow(at: "done") === window)                 // the open one comes forward unchanged
        window.close()
        #expect(controller.window == nil && controller.session == nil)
        #expect(app.calls == ["setLaunchBehavior(launchOnly)"])
        #expect(services.settings[OnboardingSettings.completedVersion] != nil)
    }

    /// A scripted capture records nothing, even when it is closed.
    @Test func aVisualQAWindowRecordsNothing() {
        _ = NSApplication.shared
        let services = OverbrightServices.preview()
        let app = PreviewAppControl()
        services.app = app
        let controller = WelcomeWindowController(services: services,
                                                 arguments: LaunchArguments(["Overbright", "--qa-welcome", "hello"]))
        let window = controller.preparedWindow(at: "hello", isVisualQA: true)
        window.close()
        #expect(app.calls.isEmpty && services.settings[OnboardingSettings.completedVersion] == nil)
    }
}
