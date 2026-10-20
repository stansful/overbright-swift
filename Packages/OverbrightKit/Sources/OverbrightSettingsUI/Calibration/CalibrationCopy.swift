// OverbrightSettingsUI/Calibration/CalibrationCopy.swift — the words of the calibration window (DESIGN.md §9, exact
// English where the design gives it): the checklist, the three steps and their buttons (title case), the results and
// the line that always follows them. "gray", not "grey" (American English, scripts/lint-copy.py).
import Foundation
import OverbrightCore
import OverbrightDesign

/// The calibration window's words.
enum CalibrationCopy {
    // MARK: Headings

    static func title(display: String) -> String {
        String(localized: "Calibrate \(display.overbrightIsolated)", bundle: .module,
               comment: "Calibration: heading of the window; the argument is the display’s name")
    }
    static var comparisonHeading: String {
        String(localized: "Does it get brighter?", bundle: .module, comment: "Calibration: heading of step 1")
    }
    static var sweepHeading: String {
        String(localized: "Where does white stop?", bundle: .module, comment: "Calibration: heading of step 2")
    }
    static var confirmationHeading: String {
        String(localized: "One more check", bundle: .module, comment: "Calibration: heading of step 3")
    }
    static var resultsHeading: String {
        String(localized: "Calibration finished", bundle: .module, comment: "Calibration: heading of the results")
    }

    // MARK: Checklist

    static func item(_ item: CalibrationChecklist.Item) -> String {
        switch item {
        case .pluggedIn:
            String(localized: "Plug in your Mac", bundle: .module, comment: "Calibration: checklist item (checked live: the power source)")
        case .maximumBrightness:
            String(localized: "Set brightness to maximum", bundle: .module, comment: "Calibration: checklist item (asked)")
        case .displayAdjustmentsOff:
            String(localized: "Overbright is at Standard now, so it’s safe to change these: turn off Automatically adjust brightness, True Tone and Night Shift in Displays settings.",
                   bundle: .module,
                   comment: "Calibration: checklist item (asked); “Automatically adjust brightness”, “True Tone”, “Night Shift” and “Displays” are macOS’s own names")
        case .noOtherApps:
            String(localized: "No other color or brightness app is running", bundle: .module,
                   comment: "Calibration: checklist item (checked live)")
        case .cool:
            String(localized: "Your Mac is cool", bundle: .module, comment: "Calibration: checklist item (checked live: the thermal state)")
        }
    }
    /// VoiceOver's value of a live checklist item that does not pass yet.
    static var notYet: String {
        String(localized: "Not yet", bundle: .module, comment: "VoiceOver: value of a calibration checklist item that does not pass yet")
    }
    static var colorimeter: String {
        String(localized: "I have a colorimeter", bundle: .module, comment: "Calibration: disclosure that reveals the SDR white field")
    }
    static var sdrWhite: String {
        String(localized: "SDR white", bundle: .module, comment: "Calibration: label of the field for white measured at Standard, in nits")
    }
    static var nitsUnit: String {
        String(localized: "nits (measured at Standard)", bundle: .module, comment: "Calibration: the unit after the SDR white field")
    }
    /// The line under the SDR white field while its value is outside the range Overbright accepts.
    static func sdrWhiteRange(locale: Locale = .autoupdatingCurrent) -> String {
        let range = CalibrationModel.plausibleSDRWhite
        let low = range.lowerBound.formatted(.number.locale(locale)), high = range.upperBound.formatted(.number.locale(locale))
        return String(localized: "Use a value from \(low) to \(high).", bundle: .module,
                      comment: "Calibration: under the SDR white field when its value is outside the range Overbright accepts; the arguments are numbers of nits such as 20 and 4,000 (the unit follows the field)")
    }
    static var start: String {
        String(localized: "calibration.start", defaultValue: "Start", bundle: .module,
               comment: "Calibration: starts the checks, or the next step (title case)")
    }
    static var cancel: String {
        String(localized: "Cancel", bundle: .module, comment: "Settings: cancel button of a confirmation (title case)")
    }

    // MARK: Step 1

    static var standard: String { LevelPreset.standard.localizedName() }
    static var brighter: String {
        String(localized: "calibration.brighter", defaultValue: "Brighter", bundle: .module,
               comment: "Calibration: the label while step 1 shows the display brighter than Standard")
    }
    static var brighterQuestion: String {
        String(localized: "Did the screen get brighter when the label said Brighter?", bundle: .module,
               comment: "Calibration: question of step 1")
    }
    static var yes: String {
        String(localized: "Yes", bundle: .module, comment: "Calibration: answer to step 1 (title case)")
    }
    static var no: String {
        String(localized: "No", bundle: .module, comment: "Calibration: answer to step 1 (title case)")
    }
    static var showAgain: String {
        String(localized: "Show Again", bundle: .module, comment: "Calibration: shows the comparison or the brighter squares again (title case)")
    }
    static var notBrighterQuestion: String {
        String(localized: "macOS seems to ignore color table changes on this Mac. Use Compatibility mode on this display?",
               bundle: .module, comment: "Calibration: question after the screen did not get brighter")
    }
    static var useCompatibilityMode: String {
        String(localized: "Use Compatibility Mode", bundle: .module, comment: "Calibration: switches the display to Compatibility mode and repeats step 1 (title case)")
    }
    static var keepColorTable: String {
        String(localized: "Keep Color Table", bundle: .module, comment: "Calibration: keeps the color table method (title case)")
    }

    // MARK: Step 2

    static func sweepInstructions(locale: Locale = .autoupdatingCurrent) -> String {
        let interval = SelfTestText.time(0.4, locale: locale)
        return String(localized: "Overbright raises extra brightness in small steps every \(interval). Watch the two squares on the right. Press Space the moment you can no longer tell them apart.",
                      bundle: .module, comment: "Calibration: instructions of step 2; the argument is a time such as 0.4 s")
    }
    static var merged: String {
        String(localized: "They Merged", bundle: .module,
               comment: "Calibration: button (and the Space key) for the moment the two squares on the right look the same (title case)")
    }
    static var pauseQuestion: String {
        String(localized: "The two squares on the right usually merge before this point. Keep going?", bundle: .module,
               comment: "Calibration: question when the sweep pauses")
    }
    static var keepGoing: String {
        String(localized: "Keep Going", bundle: .module, comment: "Calibration: continues the sweep past its pause (title case)")
    }
    static var stop: String {
        String(localized: "calibration.stop", defaultValue: "Stop", bundle: .module,
               comment: "Calibration: ends the sweep at its pause (title case)")
    }

    // MARK: Step 3

    static var confirmationQuestion: String {
        String(localized: "For two seconds the squares are shown much brighter. Can you still tell the two squares on the right apart?",
               bundle: .module, comment: "Calibration: question of step 3")
    }
    static var show: String {
        String(localized: "Show", bundle: .module, comment: "Calibration: shows the squares much brighter for two seconds (title case)")
    }
    static var lookDifferent: String {
        String(localized: "Yes, They Look Different", bundle: .module, comment: "Calibration: answer to step 3 (title case)")
    }
    static var lookTheSame: String {
        String(localized: "No, They Look the Same", bundle: .module, comment: "Calibration: answer to step 3 (title case)")
    }

    // MARK: Results

    static func result(_ ending: CalibrationModel.Ending) -> String {
        switch ending {
        case .encoded:
            String(localized: "Standard curve confirmed. Overbright keeps its default for this display.", bundle: .module,
                   comment: "Calibration: result, the display works on the standard curve")
        case .linear:
            String(localized: "This display responds in linear light. Overbright can now use more of its range.", bundle: .module,
                   comment: "Calibration: result, the display works in linear light")
        case .inconclusive:
            String(localized: "The result wasn’t clear, so Overbright keeps its safe default. You can try again.", bundle: .module,
                   comment: "Calibration: result when nothing could be decided")
        case .keptColorTable:
            String(localized: "Overbright keeps the color table on this display. If the screen doesn’t get brighter, choose Compatibility mode in Settings ▸ Displays.",
                   bundle: .module, comment: "Calibration: result after the screen did not get brighter and the color table was kept")
        }
    }
    static var turnBackOn: String {
        String(localized: "If you use Automatically adjust brightness, True Tone or Night Shift, turn them back on now, before you turn on extra brightness.",
               bundle: .module, comment: "Calibration: always follows the result; macOS’s own names of the three settings")
    }
    static func stopped(_ reason: CalibrationAbortReason) -> String? {
        switch reason {
        case .cancelled: nil
        case .noExtraRange:
            String(localized: "macOS didn’t make extra range available on this display, so the check couldn’t run.", bundle: .module,
                   comment: "Calibration: why the check ended early")
        case .headroomDropped:
            String(localized: "The check stopped because macOS lowered the extra range.", bundle: .module,
                   comment: "Calibration: why the check ended early")
        case .shielded:
            String(localized: "The check stopped because the screen locked or went to sleep.", bundle: .module,
                   comment: "Calibration: why the check ended early")
        case .occluded:
            String(localized: "The check stopped because its window was covered.", bundle: .module,
                   comment: "Calibration: why the check ended early")
        case .displayGone:
            String(localized: "The check stopped because the display was disconnected.", bundle: .module,
                   comment: "Calibration: why the check ended early")
        case .timeLimit:
            String(localized: "The check stopped after a minute.", bundle: .module, comment: "Calibration: why the check ended early")
        case .writeRefused:
            String(localized: "The check stopped to stay within what macOS allows.", bundle: .module,
                   comment: "Calibration: why the check ended early")
        }
    }
    static var unavailable: String {
        String(localized: "This display can’t be calibrated right now. Check its verdict in Settings ▸ Displays.", bundle: .module,
               comment: "Calibration: shown when no calibration could start")
    }
    static var tryAgain: String {
        String(localized: "calibration.tryAgain", defaultValue: "Try Again", bundle: .module,
               comment: "Calibration: starts the calibration again (title case)")
    }
    static var done: String {
        String(localized: "calibration.done", defaultValue: "Done", bundle: .module, comment: "Calibration: closes the window (title case)")
    }
    static var preparing: String { CommonNames.preparing() }
}
