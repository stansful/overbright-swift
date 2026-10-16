// OverbrightOnboardingTests/WelcomePlanTests.swift — the Welcome window's steps and navigation, and what the plan says
// they offer (DESIGN.md §8): the update switch only with a repository, step 4's shortcuts, the card's level. Ported
// from Cranny's WelcomePlanTests (the owner's MIT code) onto Overbright's five steps; extended by WP12.
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightOnboarding

/// A class whose bundle (the test bundle) carries no onboarding strings.
private final class BundleMarker {}

@MainActor @Suite struct WelcomePlanTests {
    @Test func fiveStepsInTheDesignsOrder() {
        let plan = WelcomePlan(updatesConfigured: false)
        #expect(plan.steps == [.hello, .displays, .defaults, .findIt, .done])
        #expect(plan.count == 5)
        #expect(plan.number(of: .displays) == 2)                                  // VoiceOver: "Step 2 of 5"
        #expect(plan.number(of: .done) == 5)
    }

    /// D2: the update switch of the last step exists only in a build with a repository.
    @Test func theUpdateToggleOnlyWhenConfigured() {
        #expect(!WelcomePlan(updatesConfigured: false).showsUpdateToggle)
        #expect(WelcomePlan(updatesConfigured: true).showsUpdateToggle)
    }

    /// A session follows the plan: the update switch with the repository it was built with.
    @Test func theSessionsPlanFollowsTheBuild() throws {
        #expect(try WelcomeHarness(updatesConfigured: true).session.plan.showsUpdateToggle)
        #expect(try !WelcomeHarness(updatesConfigured: false).session.plan.showsUpdateToggle)
    }

    /// Step 4: Turn on or off, Back to Standard, Dim Below Minimum On or Off, in this order (DESIGN.md §8); never the
    /// shortcuts without a default or the step shortcuts.
    @Test func stepFourNamesThreeShortcuts() {
        #expect(WelcomePlan.shortcuts == [.toggle, .standard, .dimToggle])
        let defaults = Set(ShortcutCatalog.all.filter { $0.defaultCombo != nil }.map(\.id))
        #expect(Set(WelcomePlan.shortcuts).isSubset(of: defaults))
    }

    /// Step 1's card shows Bright room, the default level of a newly enabled display (ARCHITECTURE.md §3.2).
    @Test func theCardShowsBrightRoom() {
        #expect(WelcomeCard.level == .brightRoom && WelcomeCard.level.position == DisplayPreferences().level)
        #expect(WelcomeCard.gain(top: 1) == 1)                                    // nothing to show without a top
        #expect(abs(WelcomeCard.gain(top: 4) - 2) < 1e-9)                        // half way in stops
    }

    @Test func navigationStopsAtBothEnds() {
        let plan = WelcomePlan(updatesConfigured: false)
        #expect(plan.previous(before: .hello) == nil)
        #expect(plan.next(after: .done) == nil)
        #expect(plan.first == .hello && plan.last == .done)
        var step = plan.first
        var visited = [step]
        while let next = plan.next(after: step) { step = next; visited.append(step) }
        #expect(visited == plan.steps)
        #expect(plan.resolve(.findIt) == .findIt)
    }

    /// `--qa-welcome <step>` and `show(step:)` take step names; unknown names are rejected (the shell shows step 1).
    @Test func stepNamesParse() {
        #expect(WelcomeStep(name: "findIt") == .findIt)
        #expect(WelcomeStep(name: "FINDIT") == .findIt)
        #expect(WelcomeStep(name: "sideways") == nil)
        #expect(WelcomeStep.allCases.allSatisfy { WelcomeStep(name: $0.rawValue) == $0 })
    }

    @Test func progressLabelReadsStepNOfCount() throws {
        // English is the catalog's source: a bundle without translations falls back to the key.
        #expect(ProgressDots.label(current: 2, count: 5, bundle: Bundle(for: BundleMarker.self)) == "Step 2 of 5")
        let russian = try #require(Bundle.onboardingStrings("ru"))
        #expect(ProgressDots.label(current: 2, count: 5, bundle: russian) == "Шаг 2 из 5")
        #expect(ProgressDots.label(current: 5, count: 2, bundle: russian) == "Шаг 5 из 2")   // the numbers keep their order
    }
}
