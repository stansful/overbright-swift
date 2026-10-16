// OverbrightOnboarding/Chrome/WelcomeSession.swift — the Welcome window's state, owned by the shell's window controller
// (DESIGN.md §8): the step and the way it moved, ↩ continues, ⌘[ goes back, Esc asks "Skip setup?", Done and Skip
// apply their choices (`WelcomeChoices`) and record that Welcome is finished, Quit Overbright records nothing, and the
// close button counts as Skip. Ported from Cranny's WelcomeFlow navigation (the owner's MIT code); the steps' own
// state is WP12's.
import Foundation
import Observation
import OverbrightCore
import os

private let log = Log.logger(.onboarding)

/// The state behind the Welcome window.
@Observable public final class WelcomeSession {
    /// The app's services (the steps read displays, settings and shortcuts through them).
    public let services: OverbrightServices
    /// The visible steps.
    let plan: WelcomePlan
    /// What Done and Skip apply.
    let choices = WelcomeChoices()
    /// The step on screen.
    public private(set) var step: WelcomeStep
    /// The last move went forward (the page transition follows it).
    private(set) var movedForward = true
    /// "Skip setup?" is up.
    var isConfirmingSkip = false
    /// Step 5 offers Turn On Overbright (WP12 sets it when a display can boost, DESIGN.md §8).
    var offersTurnOn = false
    /// How the window ended; nil while it is open.
    public private(set) var outcome: WelcomeOutcome?
    /// False in a scripted visual QA run (`--qa-welcome`): nothing is recorded or applied there.
    @ObservationIgnored private let recordsOutcome: Bool
    @ObservationIgnored private let onFinish: @MainActor (WelcomeOutcome) -> Void

    /// Welcome at `initialStep` (the first step by default). `onFinish` runs once, when it ends; the owner closes the
    /// window. `recordsOutcome` false (visual QA) leaves settings and the login item alone.
    public init(services: OverbrightServices, initialStep: WelcomeStep = .hello, recordsOutcome: Bool = true,
                onFinish: @escaping @MainActor (WelcomeOutcome) -> Void) {
        self.services = services
        plan = WelcomePlan(updatesConfigured: services.updates.isConfigured)
        step = plan.resolve(initialStep)
        self.recordsOutcome = recordsOutcome
        self.onFinish = onFinish
    }

    // MARK: Navigation

    /// 1-based number of the step on screen.
    var stepNumber: Int { plan.number(of: step) }
    /// The number of steps.
    var stepCount: Int { plan.count }
    /// ⌘[ and Back work.
    var canGoBack: Bool { plan.previous(before: step) != nil }
    /// The step on screen is the last.
    var isLastStep: Bool { plan.next(after: step) == nil }

    /// ↩ / Continue: the next step.
    func goForward() {
        guard outcome == nil, let next = plan.next(after: step) else { return }
        movedForward = true
        step = next
    }

    /// ⌘[ / Back: the previous step.
    func goBack() {
        guard outcome == nil, let previous = plan.previous(before: step) else { return }
        movedForward = false
        step = previous
    }

    /// Esc: asks "Skip setup?".
    func requestSkip() {
        guard outcome == nil else { return }
        isConfirmingSkip = true
    }

    // MARK: Ending

    /// Done: the choices apply; Turn On Overbright also turns it on (DESIGN.md §8).
    func finish(turningOn: Bool = false) {
        guard end(.done) else { return }
        if turningOn { services.boost.setOn(true, source: .welcome) }
        onFinish(.done)
    }

    /// Skip setup: every default applies, the login item included.
    func skip() {
        guard end(.skipped) else { return }
        onFinish(.skipped)
    }

    /// Quit Overbright: nothing is recorded (Welcome shows again at the next launch).
    func quit() {
        guard end(.quit) else { return }
        onFinish(.quit)
        services.app?.quit()
    }

    /// The window is closing. Before an outcome (the close button) it counts as Skip; the owner is closing it already,
    /// so `onFinish` does not run again.
    public func windowWillClose() {
        _ = end(.skipped)
    }

    /// Records `outcome` once; false when Welcome already ended.
    private func end(_ outcome: WelcomeOutcome) -> Bool {
        guard self.outcome == nil else { return false }
        self.outcome = outcome
        isConfirmingSkip = false
        log.info("welcome ended: \(String(describing: outcome), privacy: .public) at \(self.step.rawValue, privacy: .public)")
        guard recordsOutcome, outcome != .quit else { return true }
        switch outcome {
        case .done: choices.applyOnDone(to: services)
        case .skipped: choices.applyDefaults(to: services)
        case .quit: break
        }
        services.settings[OnboardingSettings.completedVersion] = AppInfo.current().version
        return true
    }
}
