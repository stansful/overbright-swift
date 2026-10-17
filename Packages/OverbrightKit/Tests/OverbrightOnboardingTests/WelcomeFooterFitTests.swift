// OverbrightOnboardingTests/WelcomeFooterFitTests.swift — the Welcome footer (Quit Overbright, the progress dots, Back
// and Continue, or Done and Turn On Overbright) fits the 640-pt window between its side insets (DESIGN.md §8, §16:
// "constrained strings are measured … English and a pseudo-long locale during development, all 35 in WP15";
// ARCHITECTURE.md §9.1 UI row). Measured, never counted: the rows' ideal widths as SwiftUI lays them out, and the dots
// as drawn. Every footer shows its dots, centred in the window (WP14 C-ONBOARD-1), the last step's with Turn On
// Overbright included, in English, the pseudo-long locale and every language Overbright ships (WP15): in the row while
// the buttons leave the centre free, else just above it. No translation may push a button out of the row, and only
// the last step with Turn On Overbright may need the dots' own line (the page is measured under that footer there).
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI
import Testing
@testable import OverbrightOnboarding

/// A class of this test bundle: a bundle without translations, so `String(localized:bundle:)` gives the English keys.
private final class EnglishMarker {}

@MainActor @Suite struct WelcomeFooterFitTests {
    /// The footer's titles in English, whatever language the test process runs in.
    static var english: WelcomeFooter.Labels { .localized(in: Bundle(for: EnglishMarker.self)) }

    /// The width the footer row gets: the window minus its side insets.
    static let budget = WelcomeMetrics.window.width - 2 * WelcomeMetrics.inset

    /// Every kind of footer: first step, a middle one, the last one without and with Turn On Overbright.
    static func sessions() -> [(String, WelcomeSession)] {
        [("first", WelcomeChromeSnapshotTests.session(.hello)), ("middle", WelcomeChromeSnapshotTests.session(.defaults)),
         ("last", WelcomeChromeSnapshotTests.session(.done)),
         ("last, Turn On", WelcomeChromeSnapshotTests.session(.done, turnOn: true))]
    }

    /// The footer of `session` with `labels`: its button row fits the window's row (with the dots above it, the
    /// narrowest footer), and it draws its dots, centred in the window. Returns where it draws them.
    @discardableResult
    static func expectFitsWithDots(_ name: String, _ session: WelcomeSession, _ labels: WelcomeFooter.Labels,
                                   sourceLocation: SourceLocation = #_sourceLocation)
        throws -> WelcomeFooter.DotsPlacement {
        let width = FitMeasure.idealWidth(WelcomeFooter(session: session, labels: labels).row(dots: .aboveRow))
        #expect(width > 0 && width <= budget, "\(name): the buttons need \(width) pt of \(budget)",
                sourceLocation: sourceLocation)
        let drawn = try WelcomeLayoutTests.drawnDots(session, labels: labels)
        let extent = try #require(drawn.extent, "\(name): no dots", sourceLocation: sourceLocation)
        #expect(WelcomeLayoutTests.isCentredDots(extent), "\(name): the dots are drawn at \(extent)",
                sourceLocation: sourceLocation)
        return drawn.placement
    }

    /// In English every footer shows its dots, the last step's with Turn On Overbright included: in the row on every
    /// footer whose buttons leave the centre free (as before WP14), just above it on the last step with Turn On
    /// Overbright.
    @Test func everyFooterFitsWithItsDotsInEnglish() throws {
        #expect(Self.sessions().map(\.0) == ["first", "middle", "last", "last, Turn On"])
        for (name, session) in Self.sessions() {
            let placement = try Self.expectFitsWithDots(name, session, Self.english)
            #expect(placement == (name == "last, Turn On" ? .aboveRow : .inRow), "\(name): \(placement)")
            if placement == .inRow {
                let width = FitMeasure.idealWidth(WelcomeFooter(session: session, labels: Self.english)
                    .row(dots: .inRow))
                #expect(width <= Self.budget, "\(name): \(width) pt of \(Self.budget)")
            }
        }
    }

    /// +40 %: every button still fits, and every footer keeps its dots.
    @Test func everyFooterFitsInThePseudoLongLocale() throws {
        let long = Self.english.map(PseudoLocale.lengthen)
        #expect(long.turnOn.count > Self.english.turnOn.count && Self.english.turnOn == "Turn On Overbright")
        for (name, session) in Self.sessions() {
            try Self.expectFitsWithDots("\(name), pseudo-long", session, long)
        }
    }

    /// Offered the window's row, the footer as drawn never leaves it.
    @Test func theRenderedFooterNeverLeavesItsRow() {
        for labels in [Self.english, Self.english.map(PseudoLocale.lengthen)] {
            for (name, session) in Self.sessions() {
                let width = FitMeasure.width(WelcomeFooter(session: session, labels: labels), offered: Self.budget)
                #expect(width <= Self.budget, "\(name): \(width) pt")
            }
        }
    }

    /// WP15: in every language Overbright ships, every button fits the row, every footer shows its dots centred in the
    /// window, only the last step with Turn On Overbright puts them on their own line, and the footer as drawn never
    /// leaves its row.
    @Test(arguments: CopyLanguage.available)
    func everyFooterFitsInEveryLanguage(_ code: String) throws {
        let labels = WelcomeFooter.Labels.localized(in: onboardingBundle(code))
        for (name, session) in Self.sessions() {
            let placement = try Self.expectFitsWithDots("\(code), \(name)", session, labels)
            #expect(placement == .inRow || name == "last, Turn On", "\(code), \(name): the dots leave the row")
            let drawn = FitMeasure.width(WelcomeFooter(session: session, labels: labels), offered: Self.budget)
            #expect(drawn <= Self.budget, "\(code), \(name): \(drawn) pt")
        }
    }

    /// The footer's five titles are five different strings, the same ones the Skip alert shares (Quit Overbright).
    @Test func theLabelsAreTheLocalizedCopy() {
        let labels = WelcomeFooter.Labels.localized
        let titles = [labels.quit, labels.back, labels.proceed, labels.done, labels.turnOn]
        #expect(Set(titles).count == 5 && titles.allSatisfy { !$0.isEmpty })
        #expect(labels.quit == OnboardingCopy.quit && labels.done == OnboardingCopy.done)
    }
}
