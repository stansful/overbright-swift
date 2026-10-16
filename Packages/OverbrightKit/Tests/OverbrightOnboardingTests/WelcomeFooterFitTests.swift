// OverbrightOnboardingTests/WelcomeFooterFitTests.swift — the Welcome footer row (Quit Overbright, the progress dots,
// Back and Continue, or Done and Turn On Overbright) fits the 640-pt window between its side insets (DESIGN.md §8, §16:
// "constrained strings are measured … English and a pseudo-long locale during development, all 35 in WP15";
// ARCHITECTURE.md §9.1 UI row). Measured, never counted: the row's ideal width as SwiftUI lays it out. In English every
// row fits with its progress dots; a long translation may only push the dots out, never a button (measured in every
// language Overbright ships, WP15).
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

    @Test func everyFooterFitsWithItsDotsInEnglish() {
        for (name, session) in Self.sessions() {
            let width = FitMeasure.idealWidth(WelcomeFooter(session: session, labels: Self.english).row(showsDots: true))
            #expect(width > 0 && width <= Self.budget, "\(name): \(width) pt of \(Self.budget)")
        }
    }

    /// +40 %: every button still fits; on the last step with Turn On Overbright the dots step aside.
    @Test func everyFooterFitsInThePseudoLongLocale() {
        let long = Self.english.map(PseudoLocale.lengthen)
        #expect(long.turnOn.count > Self.english.turnOn.count && Self.english.turnOn == "Turn On Overbright")
        for (name, session) in Self.sessions() {
            let footer = WelcomeFooter(session: session, labels: long)
            let full = FitMeasure.idealWidth(footer.row(showsDots: true))
            let withoutDots = FitMeasure.idealWidth(footer.row(showsDots: false))
            #expect(full <= Self.budget || withoutDots <= Self.budget,
                    "\(name), pseudo-long: \(full) pt with the dots, \(withoutDots) pt without, of \(Self.budget)")
            #expect(withoutDots < full, "\(name)")
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

    /// WP15: in every language Overbright ships, every button fits the row (the progress dots may step aside), and the
    /// footer as drawn never leaves it.
    @Test(arguments: CopyLanguage.available)
    func everyFooterFitsInEveryLanguage(_ code: String) {
        let labels = WelcomeFooter.Labels.localized(in: onboardingBundle(code))
        for (name, session) in Self.sessions() {
            let footer = WelcomeFooter(session: session, labels: labels)
            let full = FitMeasure.idealWidth(footer.row(showsDots: true))
            let withoutDots = FitMeasure.idealWidth(footer.row(showsDots: false))
            #expect(full <= Self.budget || withoutDots <= Self.budget,
                    "\(code), \(name): \(full) pt with the dots, \(withoutDots) pt without, of \(Self.budget)")
            let drawn = FitMeasure.width(footer, offered: Self.budget)
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
