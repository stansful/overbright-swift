// OverbrightDesignTests/BannerModelTests.swift — DESIGN.md §12.3: every banner's sentence and primary action, the
// status menu's title-case action, display names isolated, and the variants without a name.
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightDesign

@Suite struct BannerModelTests {
    nonisolated static let booster = ConflictingApp(entryID: "s1", severity: .booster, bundleID: nil, processID: 1, displayName: "Booster")
    nonisolated static let colorApp = ConflictingApp(entryID: "s2", severity: .gammaWriter, bundleID: nil, processID: 2, displayName: "Warmth")
    nonisolated static let display = DisplayKey(rawValue: "A")
    nonisolated static let names = [display: "Studio Display"]
    /// 14:20 GMT on 2026-10-16.
    nonisolated static let twentyPastTwo = Date(timeIntervalSince1970: 1_792_160_400)

    private func banner(_ banner: Banner, names: [DisplayKey: String] = names,
                        language: CopyLanguage = english) -> BannerModel {
        BannerModel.make(banner, displayNames: names, in: language)
    }

    @Test func theBannerTable() {
        typealias Row = (Banner, String, FixAction?)
        let rows: [Row] = [
            (.conflict(Self.booster),
             "Paused because \u{2068}Booster\u{2069} also changes display brightness. Quit it, or use Compatibility mode, which works alongside it.",
             .useCompatibilityMode),
            (.conflict(Self.colorApp),
             "Paused because \u{2068}Warmth\u{2069} changes display colors. Night Shift gives warm light without a conflict.",
             .continueAnyway),
            (.foreignTableAtLaunch,
             "Another app changed the display colors and they couldn’t be reset. Change the color profile or preset in Displays settings and back, or log out.",
             .openSystemSettings),
            (.flickerStop(display: Self.display), "Overbright stopped on \u{2068}Studio Display\u{2069} to prevent flicker.", .tryAgain),
            (.unattributedDrift(display: Self.display),
             "Another app keeps changing the colors of \u{2068}Studio Display\u{2069}, so Overbright stopped there.", .tryAgain),
            (.attributedDrift(Self.colorApp, display: Self.display),
             "\u{2068}Warmth\u{2069} changed the colors of \u{2068}Studio Display\u{2069}, so Overbright stopped there.", .continueAnyway),
            (.focusOff, "Off because of the current Focus.", .openSystemSettings),
            (.thermalCritical, "Paused because your Mac is hot. Overbright continues when it cools down.", nil),
            (.lowPowerMode, "Paused because Low Power Mode is on.", .changePowerRules),
            (.battery(percent: 12, threshold: 20), "Paused because the battery is below 20%.", .changePowerRules),
            (.onBattery, "Paused while on battery.", .changePowerRules),
        ]
        for (value, sentence, action) in rows {
            let model = banner(value)
            #expect(model.sentence == sentence, "\(value)")
            #expect(model.primaryAction == action, "\(value)")
            #expect(model.primaryTitle == action?.title(in: english), "\(value)")
            #expect(model.secondaryTitle == nil)
        }
    }

    @Test func pauseAndScheduleSayTheTimeInTheLocalesClock() {
        let german = CopyLanguage(bundle: english.bundle, locale: Locale(identifier: "de_DE"), timeZone: .gmt)
        #expect(banner(.userPaused(until: Self.twentyPastTwo), language: german).sentence == "Overbright is paused until 14:20.")
        #expect(banner(.userPaused(until: Self.twentyPastTwo)).sentence == "Overbright is paused until 2:20\u{202F}PM.")
        #expect(banner(.userPaused(until: Self.twentyPastTwo)).primaryAction == .resume)
        let schedule = banner(.outsideSchedule(ScheduleWindow(startMinute: 8 * 60, endMinute: 20 * 60)), language: german)
        #expect(schedule.sentence.hasPrefix("Extra brightness is allowed from ")
                && schedule.sentence.contains("8:00 to 20:00."), "\(schedule.sentence)")
        #expect(schedule.primaryAction == .changeHours)
    }

    /// The status menu repeats the primary action in title case (DESIGN.md §12.3).
    @Test func theMenuActionIsTitleCase() {
        #expect(banner(.lowPowerMode).primaryMenuTitle == "Change Power Rules…")
        #expect(banner(.conflict(Self.booster)).primaryMenuTitle == "Use Compatibility Mode")
        #expect(banner(.conflict(Self.colorApp)).primaryMenuTitle == "Continue Anyway")
        #expect(banner(.flickerStop(display: Self.display)).primaryMenuTitle == "Try Again")
        #expect(banner(.focusOff).primaryMenuTitle == "Open System Settings")
        #expect(banner(.outsideSchedule(ScheduleWindow(startMinute: 0, endMinute: 60))).primaryMenuTitle == "Change Hours…")
    }

    @Test func aStopOnAnUnknownDisplayStillReads() {
        #expect(banner(.flickerStop(display: Self.display), names: [:]).sentence
                == "Overbright stopped on a display to prevent flicker.")
        #expect(banner(.unattributedDrift(display: Self.display), names: [:]).sentence
                == "Another app keeps changing the colors of a display, so Overbright stopped there.")
        #expect(banner(.attributedDrift(Self.colorApp, display: Self.display), names: [:]).sentence
                == "\u{2068}Warmth\u{2069} changed the colors of a display, so Overbright stopped there.")
    }

    /// Danger for stops, warning for conflicts and heat, neutral for pauses; the moon only for Focus.
    @Test func coloursAndGlyphs() {
        #expect(banner(.flickerStop(display: Self.display)).color == .danger)
        #expect(banner(.foreignTableAtLaunch).color == .danger)
        #expect(banner(.conflict(Self.booster)).color == .warning)
        #expect(banner(.lowPowerMode).color == .neutral)
        #expect(banner(.focusOff).symbol == .moonFill)
        #expect(banner(.thermalCritical).symbol == .thermometerHigh)
    }

    /// The fixed seam builds the same words in the app's language.
    @Test func theSeamBuilds() {
        #expect(!BannerModel.make(.lowPowerMode).sentence.isEmpty)
        #expect(BannerModel.make(.lowPowerMode).primaryAction == .changePowerRules)
    }
}
