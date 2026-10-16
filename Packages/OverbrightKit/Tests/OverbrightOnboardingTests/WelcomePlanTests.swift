// OverbrightOnboardingTests/WelcomePlanTests.swift — the Welcome window's steps and navigation (DESIGN.md §8). Ported
// from Cranny's WelcomePlanTests (the owner's MIT code) onto Overbright's five steps; WP12 extends them.
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
