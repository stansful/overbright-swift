// OverbrightOnboardingTests/WelcomeSessionTests.swift — the Welcome chrome's behaviour (DESIGN.md §8): ↩ / ⌘[ move
// between steps, Esc asks before skipping, Skip and the close button apply the defaults (the login item through
// `AppControl`) and record that Welcome is finished, Done applies the choices, Quit records nothing, and a visual QA
// run records and applies nothing. Against `OverbrightServices.preview()`: nothing real is registered or written.
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightOnboarding

@MainActor private func makeSession(step: WelcomeStep = .hello, records: Bool = true)
    -> (WelcomeSession, OverbrightServices, PreviewAppControl, Box) {
    let services = OverbrightServices.preview()
    let app = PreviewAppControl()
    services.app = app
    let box = Box()
    let session = WelcomeSession(services: services, initialStep: step, recordsOutcome: records) { box.outcomes.append($0) }
    return (session, services, app, box)
}

/// The outcomes `onFinish` reported.
@MainActor private final class Box { var outcomes: [WelcomeOutcome] = [] }

@MainActor @Suite struct WelcomeSessionTests {
    @Test func continueAndBackWalkTheSteps() {
        let (session, _, _, _) = makeSession()
        #expect(session.step == .hello && !session.canGoBack && session.stepNumber == 1 && session.stepCount == 5)
        session.goBack()                                                          // nothing before step 1
        #expect(session.step == .hello)
        session.goForward()
        #expect(session.step == .displays && session.movedForward && session.canGoBack)
        session.goBack()
        #expect(session.step == .hello && !session.movedForward)
        for _ in 0..<10 { session.goForward() }
        #expect(session.step == .done && session.isLastStep)
    }

    /// Esc asks first; the alert's Skip applies every default, the login item included, and records completion.
    @Test func skipAppliesTheDefaultsAndRecordsCompletion() {
        let (session, services, app, box) = makeSession(step: .defaults)
        session.choices.launchBehavior = .dontLaunch                            // chosen, then skipped: defaults win
        session.requestSkip()
        #expect(session.isConfirmingSkip && box.outcomes.isEmpty)
        session.skip()
        #expect(box.outcomes == [.skipped] && session.outcome == .skipped && !session.isConfirmingSkip)
        #expect(app.calls == ["setLaunchBehavior(launchOnly)"])
        #expect(services.settings[OnboardingSettings.completedVersion] != nil)
    }

    /// The close button before an outcome counts as Skip; the window is closing already, so `onFinish` stays quiet.
    @Test func theCloseButtonCountsAsSkip() {
        let (session, services, app, box) = makeSession(step: .findIt)
        session.windowWillClose()
        #expect(session.outcome == .skipped && box.outcomes.isEmpty)
        #expect(app.calls == ["setLaunchBehavior(launchOnly)"])
        #expect(services.settings[OnboardingSettings.completedVersion] != nil)
        session.windowWillClose()                                                // once
        #expect(app.calls.count == 1)
    }

    @Test func doneAppliesTheChoices() {
        let (session, services, app, box) = makeSession(step: .done)
        session.choices.launchBehavior = .launchAndEnable
        session.finish()
        #expect(box.outcomes == [.done])
        #expect(app.calls == ["setLaunchBehavior(launchAndEnable)"])
        #expect(services.settings[OnboardingSettings.completedVersion] != nil)
        #expect(!services.boost.status.isOn)                                     // Done alone does not turn it on
    }

    @Test func turnOnOverbrightTurnsItOn() {
        let (session, services, _, box) = makeSession(step: .done)
        session.finish(turningOn: true)
        #expect(box.outcomes == [.done] && services.boost.status.isOn)
    }

    /// Quit Overbright records nothing: Welcome shows again at the next launch.
    @Test func quitRecordsNothing() {
        let (session, services, app, box) = makeSession(step: .displays)
        session.quit()
        #expect(box.outcomes == [.quit] && app.calls == ["quit"])
        #expect(services.settings[OnboardingSettings.completedVersion] == nil)
        session.windowWillClose()                                                // the quit closes it: no Skip after it
        #expect(session.outcome == .quit && app.calls == ["quit"])
    }

    /// Quitting Overbright while Welcome is open (⌘Q, a script) is a quit, not a Skip: Welcome shows again next time.
    @Test func quittingTheAppWhileOpenRecordsNothing() {
        let (session, services, app, box) = makeSession(step: .defaults)
        session.appWillTerminate()
        #expect(session.outcome == .quit && box.outcomes.isEmpty && app.calls.isEmpty)
        #expect(services.settings[OnboardingSettings.completedVersion] == nil)
    }

    /// A scripted visual QA run (`--qa-welcome`) applies and records nothing.
    @Test func visualQARecordsNothing() {
        let (session, services, app, box) = makeSession(records: false)
        session.skip()
        #expect(box.outcomes == [.skipped] && app.calls.isEmpty)
        #expect(services.settings[OnboardingSettings.completedVersion] == nil)
    }

    /// Nothing moves once Welcome ended.
    @Test func anEndedSessionIgnoresInput() {
        let (session, _, _, box) = makeSession()
        session.skip()
        session.goForward()
        session.requestSkip()
        session.finish()
        #expect(session.step == .hello && !session.isConfirmingSkip && box.outcomes == [.skipped])
    }
}
