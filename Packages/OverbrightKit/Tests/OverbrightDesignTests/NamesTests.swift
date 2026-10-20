// OverbrightDesignTests/NamesTests.swift — the user-facing names of Core and Policy enums live in Design (ARCHITECTURE.md
// §2.1 rule 5, §8.8): every case has a name, names of one enum differ, menu actions use title case, the vocabulary
// of DESIGN.md §16 holds, and every action names its destination.
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightDesign

@Suite struct NamesTests {
    private func distinct(_ names: [String], _ what: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(names.allSatisfy { !$0.isEmpty }, "\(what): \(names)", sourceLocation: sourceLocation)
        #expect(Set(names).count == names.count, "\(what): \(names)", sourceLocation: sourceLocation)
    }

    @Test func everyCaseHasItsOwnName() {
        distinct(LevelPreset.allCases.map { $0.localizedName(in: english) }, "presets")
        distinct(CapMode.allCases.map { $0.localizedName(in: english) }, "cap modes")
        distinct(TriggerStrategy.allCases.map { $0.localizedName(in: english) }, "trigger methods")
        distinct([TriggerPixel.black, .sdrWhite, .bright].map { $0.localizedName(in: english) }, "pixels")
        distinct([OLEDOverride.automatic, .oled, .notOLED].flatMap { [$0.localizedName(detectedOLED: true, in: english),
                                                                       $0.localizedName(detectedOLED: false, in: english)] }
                 .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }, "display types")
        distinct(BatteryGuard.allCases.map { $0.localizedName(in: english) }, "battery guards")
        distinct([PausedAppRule.Mode.whileFrontmost, .whilePlaying].map { $0.localizedName(in: english) }, "app modes")
        distinct([CameraFilter.anyCamera, .builtInAndUSB].map { $0.localizedName(in: english) }, "cameras")
        distinct(LaunchBehavior.allCases.map { $0.localizedName(in: english) }, "launch")
        distinct(StatusClickAction.allCases.map { $0.localizedName(in: english) }, "click")
        distinct(StepSize.allCases.map { $0.localizedName(in: english) }, "step size")
        distinct([SelfTestStrategyResult.Verdict.held, .engagedButDropped, .noEngage, .invalidBaseline, .skipped]
                 .map { $0.localizedName(in: english) }, "self-test results")
        distinct(ConflictSeverity.allCases.compactMap { $0.localizedKind(in: english) }, "other apps")
        distinct(FixAction.allCases.map { $0.title(in: english) }, "actions")
        distinct(FixAction.allCases.map { $0.menuTitle(in: english) }, "menu actions")
    }

    /// The words of DESIGN.md §7 and §12.
    @Test func theWords() {
        #expect(LevelPreset.brightRoom.localizedName(in: english) == "Bright room")
        #expect(CapMode.allCases.map { $0.localizedName(in: english) } == ["Safe", "Peak"])
        #expect(TriggerStrategy.allCases.map { $0.localizedName(in: english) }
                == ["Tagged layer", "Metal layer", "Metal layer, refreshed", "HDR frame", "HDR video still"])
        #expect(TriggerStrategy.taggedLayer.localizedName(pixel: .black, in: english) == "Tagged layer, black")
        #expect(OLEDOverride.automatic.localizedName(detectedOLED: true, in: english) == "Automatic (OLED)")
        #expect(LaunchBehavior.dontLaunch.localizedName(in: english) == "Don’t open Overbright")
        #expect(SelfTestStrategyResult.Verdict.invalidBaseline.localizedName(in: english) == "Already bright")
        #expect(ConflictSeverity.benign.localizedKind(in: english) == nil)
        let record = CalibrationRecord(outcome: .encoded, mergeFactor: 1.6, estimatedExponent: nil,
                                       measuredSDRWhiteNits: nil, headroomAtTest: 2.667, potentialAtTest: 16, osBuild: "27A1",
                                       measuredAt: Date(timeIntervalSince1970: 0))
        #expect(CalibrationText.make(record, isValid: true, osVersion: "27.0.1", in: english) == "Standard curve (macOS 27.0.1)")
        #expect(CalibrationText.make(record, isValid: false, osVersion: "27.0.1", in: english)
                == "Check again: macOS, the preset or the method changed")
        #expect(CalibrationText.make(nil, isValid: true, osVersion: "27.0.1", in: english) == "Not calibrated")
    }

    /// DESIGN.md §16: "Max" never names a ceiling; "boost", "EDR", "gamma" and "headroom" never reach user copy here.
    @Test func theVocabulary() {
        let ceilings = CapMode.allCases.map { $0.localizedName(in: english) }
        #expect(!ceilings.contains("Max"))
        let words = FixAction.allCases.map { $0.title(in: english) } + LevelPreset.allCases.map { $0.localizedName(in: english) }
        for word in words {
            for banned in ["EDR", "gamma", "headroom", "boost", "Dimmer"] {
                #expect(!word.localizedCaseInsensitiveContains(banned), "\(word) uses “\(banned)”")
            }
        }
    }

    /// A button that opens System Settings is always "Open System Settings"; one into Overbright names the action.
    @Test func destinationsAreUnambiguous() {
        #expect(FixAction.openSystemSettings.title(in: english) == "Open System Settings")
        for action in FixAction.allCases where action != .openSystemSettings {
            #expect(!action.title(in: english).contains("Settings"), "\(action)")
        }
        #expect(FixAction.choosePeak.title(in: english) == "Choose Peak…")
        #expect(FixAction.changePowerRules.menuTitle(in: english) == "Change Power Rules…")
    }

    /// The shortcuts' names in Settings ▸ Shortcuts (DESIGN.md §7.6, §16).
    @Test func shortcutNames() {
        let ids: [ShortcutID] = ShortcutCatalog.all.map(\.id)
        #expect(ids.compactMap { $0.localizedName(in: english) }
                == ["Turn Overbright on or off", "Brighter", "Less Bright", "Max", "Back to Standard",
                    "Dim Below Minimum On or Off", "Fill Light"])
        #expect(ShortcutID("boost.unknown").localizedName(in: english) == nil)
        #expect(StepDirection.brighter.localizedName(in: english) == "Brighter")
        #expect(StepDirection.lessBright.localizedName(in: english) == "Less Bright")
        distinct(ids.compactMap { $0.localizedName(in: english) }, "shortcut names")
        for name in ids.compactMap({ $0.localizedName(in: english) }) {
            #expect(!name.localizedCaseInsensitiveContains("Dimmer"), "\(name) (DESIGN.md §16)")
        }
    }

    /// The inline results of Settings ▸ Advanced ▸ Reset Display Colors (DESIGN.md §12.4).
    @Test func resetDisplayColorsResults() {
        let app = ConflictingApp(entryID: "s2", severity: .gammaWriter, bundleID: "com.example.colors", processID: 2,
                                 displayName: "Colors")
        let display = DisplayKey(rawValue: "A")
        let rows: [(RescueOutcome, String)] = [
            (.restored(displays: 2), "Display colors reset."),
            (.alreadyNeutral, "Display colors were already normal."),
            (.repairedInvalidRestore(displays: [display]),
             "Display colors reset. Some displays were set back to their color profile directly."),
            (.skippedBecauseTableWriterRuns(app), "Another brightness or color app is running. Quit it first."),
            (.residueRemains(displays: [display]),
             "Some colors couldn’t be reset. Change the color profile in Displays settings and back, or log out."),
            (.skippedNotOnConsole, "Display colors can be reset only from the session shown on the displays."),
        ]
        for (outcome, sentence) in rows { #expect(outcome.localizedResult(in: english) == sentence, "\(outcome)") }
        distinct(rows.map { $0.0.localizedResult(in: english) }, "rescue results")
    }
}
