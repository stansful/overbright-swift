// OverbrightSettingsUI/SelfTest/SelfTestText.swift — the words of the self-test sheet (DESIGN.md §10): the consent text,
// the progress line ("Built-in Display · Tagged layer, black · 12 s"), the times of the results table, the summary
// line per display ("Built-in Display: Tagged layer works. It will be used from now on.") and the privacy note.
// Method and result names are Design's (`TriggerStrategy`, `SelfTestStrategyResult.Verdict`).
import Foundation
import OverbrightCore
import OverbrightDesign

/// The self-test sheet's words.
enum SelfTestText {
    static var title: String {
        String(localized: "Self-Test", bundle: .module, comment: "Self-test: title of the sheet")
    }

    static var intro: String {
        String(localized: "For about a minute per display, Overbright unlocks extra range and records how macOS responds. Your brightness doesn’t change, but a tiny dot may appear in a corner of the display being tested. Keep your Mac awake and unlocked.",
               bundle: .module, comment: "Self-test: what the test does, before it runs")
    }

    static var everyMethod: String {
        String(localized: "Test every method", bundle: .module, comment: "Self-test: checkbox that tests every method instead of stopping at the first that works")
    }

    static var everyMethodNote: String {
        String(localized: "About 3 minutes per display.", bundle: .module, comment: "Self-test: note beside Test every method")
    }

    static var run: String {
        String(localized: "Run Self-Test", bundle: .module, comment: "Self-test: starts the test (title case)")
    }

    static var stop: String {
        String(localized: "Stop", bundle: .module, comment: "Self-test: stops the running test; everything returns to normal at once (title case)")
    }

    static var saveLog: String {
        String(localized: "Save Log…", bundle: .module, comment: "Self-test: saves the results as a file (title case)")
    }

    static var copy: String {
        String(localized: "Copy", bundle: .module, comment: "Self-test: copies the results to the clipboard (title case)")
    }

    static var done: String {
        String(localized: "selfTest.done", defaultValue: "Done", bundle: .module, comment: "Self-test: closes the sheet (title case)")
    }

    /// The name of a display in a report that is not connected any more.
    static var unknownDisplay: String {
        String(localized: "A display that is not connected", bundle: .module,
               comment: "Self-test: name of a display in the results that was disconnected since the test")
    }

    static var privacy: String {
        String(localized: "The log contains display models, the macOS version and measurements. It never contains your files, window titles or app names.",
               bundle: .module, comment: "Self-test: privacy note beside the results")
    }

    /// Column headers of the results table.
    static var methodColumn: String {
        String(localized: "selfTest.column.method", defaultValue: "Method", bundle: .module,
               comment: "Self-test: column header of the results table (the trigger method)")
    }
    static var resultColumn: String {
        String(localized: "Result", bundle: .module, comment: "Self-test: column header of the results table")
    }
    static var responseColumn: String {
        String(localized: "Response time", bundle: .module, comment: "Self-test: column header, time until macOS first gave extra range")
    }
    static var steadyColumn: String {
        String(localized: "Steady time", bundle: .module, comment: "Self-test: column header, time until the extra range held steady")
    }

    /// "Built-in Display · Tagged layer, black · 12 s".
    static func progress(display: String, rung: SelfTestPlan.Rung, seconds: Int, locale: Locale = .autoupdatingCurrent) -> String {
        let method = rung.strategy.localizedName(pixel: rung.pixel)
        let time = Duration.seconds(seconds).formatted(.units(allowed: [.seconds], width: .narrow).locale(locale))
        return CopyFormat.parts(CopyFormat.parts(display, method), time)
    }

    /// A time in the table ("1.2 s"), or "—" when it never happened.
    static func time(_ seconds: Double?, locale: Locale = .autoupdatingCurrent) -> String {
        guard let seconds, seconds.isFinite else { return "—" }
        let value = seconds.formatted(.number.precision(.fractionLength(1)).locale(locale))
        return String(localized: "\(value) s", bundle: .module,
                      comment: "Self-test: a time in the results table in seconds, as in “1.2 s”; the number is preformatted")
    }

    /// The summary of one display: the method that will be used, or that none held.
    static func summary(display: String, results: [SelfTestStrategyResult]) -> String {
        guard let winner = SelfTestPlan.cleanWinner(in: results) else {
            return String(localized: "\(display.overbrightIsolated): No method held extra range.", bundle: .module,
                          comment: "Self-test: summary of a display where no method kept extra range; the argument is the display’s name")
        }
        let method = winner.strategy.localizedName()
        return String(localized: "\(display.overbrightIsolated): \(method) works. It will be used from now on.", bundle: .module,
                      comment: "Self-test: summary of a display after a clean pass; the arguments are the display’s name and the method’s name")
    }
}
