// OverbrightOnboarding/Model/WelcomePlan.swift — which steps the Welcome window shows, in what order, and what they
// offer on this build (pure). DESIGN.md §8. Ported from Cranny's WelcomePlan (the owner's MIT code); seeded by WP0b
// (ARCHITECTURE.md §10.2), owned by WP12 (§10.14). What depends on this Mac's displays, settings and shortcuts is
// read live by the steps (`WelcomeDisplayRow`, `WelcomeCard`, `FindItShortcut`), so a change shows at once.
import Foundation
import OverbrightCore

/// The visible steps for this Mac. Numbers are 1-based, as VoiceOver reads them ("Step 2 of 5").
nonisolated struct WelcomePlan: Equatable, Sendable {
    /// The steps in order.
    let steps: [WelcomeStep]
    /// The Done step's "Check for updates on GitHub" switch: only when this build has a repository (D2).
    let showsUpdateToggle: Bool

    /// The shortcuts step 4 shows, in order, when registered: Turn on or off, Back to Standard, Dim Below Minimum On
    /// or Off (DESIGN.md §8).
    static let shortcuts: [ShortcutID] = [.toggle, .standard, .dimToggle]

    /// The plan for a build with (`updatesConfigured`) or without an update check.
    init(updatesConfigured: Bool) {
        steps = WelcomeStep.allCases
        showsUpdateToggle = updatesConfigured
    }

    /// The number of steps.
    var count: Int { steps.count }
    /// The first step.
    var first: WelcomeStep { steps.first ?? .hello }
    /// The last step.
    var last: WelcomeStep { steps.last ?? .done }

    /// 1-based position of a visible step (a hidden step reports the position of the step that replaces it).
    func number(of step: WelcomeStep) -> Int {
        (steps.firstIndex(of: resolve(step)) ?? 0) + 1
    }

    /// The step after `step`; nil on the last.
    func next(after step: WelcomeStep) -> WelcomeStep? {
        guard let index = steps.firstIndex(of: resolve(step)), index + 1 < steps.count else { return nil }
        return steps[index + 1]
    }

    /// The step before `step`; nil on the first.
    func previous(before step: WelcomeStep) -> WelcomeStep? {
        guard let index = steps.firstIndex(of: resolve(step)), index > 0 else { return nil }
        return steps[index - 1]
    }

    /// The step to show for a requested one: a hidden step falls through to the next visible step.
    func resolve(_ step: WelcomeStep) -> WelcomeStep {
        if steps.contains(step) { return step }
        let later = WelcomeStep.allCases.drop { $0 != step }
        return later.first(where: steps.contains) ?? last
    }
}
