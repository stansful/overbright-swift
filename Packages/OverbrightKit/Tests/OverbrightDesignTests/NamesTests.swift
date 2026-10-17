// OverbrightDesignTests/NamesTests.swift — the user-facing names of Core and Policy enums live in Design (ARCHITECTURE.md
// §2.1 rule 5, §8.8): every case has a name, names of one enum differ, menus use title case, the vocabulary of
// DESIGN.md §16 holds, and every action names its destination.
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
        distinct(LevelPreset.allCases.map { $0.menuTitle(in: english) }, "preset menu titles")
        distinct(CapMode.allCases.map { $0.localizedName(in: english) }, "cap modes")
        distinct(MechanismPreference.allCases.map { $0.localizedName(in: english) }, "methods")
        distinct(TriggerStrategy.allCases.map { $0.localizedName(in: english) }, "trigger methods")
        distinct([TriggerPixel.black, .sdrWhite, .bright].map { $0.localizedName(in: english) }, "pixels")
        distinct([OLEDOverride.automatic, .oled, .notOLED].flatMap { [$0.localizedName(detectedOLED: true, in: english),
                                                                       $0.localizedName(detectedOLED: false, in: english)] }
                 .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }, "display types")
        distinct(BatteryGuard.allCases.map { $0.localizedName(in: english) }, "battery guards")
        distinct(BatteryGuard.allCases.map { $0.menuTitle(in: english) }, "battery menu")
        distinct([PausedAppRule.Mode.whileFrontmost, .whilePlaying].map { $0.localizedName(in: english) }, "app modes")
        distinct([CameraFilter.anyCamera, .builtInAndUSB].map { $0.localizedName(in: english) }, "cameras")
        distinct(LaunchBehavior.allCases.map { $0.localizedName(in: english) }, "launch")
        distinct(LaunchBehavior.allCases.map { $0.shortName(in: english) }, "launch (Welcome)")
        distinct(StatusClickAction.allCases.map { $0.localizedName(in: english) }, "click")
        distinct(StepSize.allCases.map { $0.localizedName(in: english) }, "step size")
        distinct(StatusSymbolState.allCases.map { $0.accessibilityLabel(in: english) }, "symbol labels")
        distinct(StatusSymbolState.allCases.map { $0.accessibilityValue(in: english) }, "symbol values")
        distinct([SelfTestStrategyResult.Verdict.held, .engagedButDropped, .noEngage, .invalidBaseline, .skipped]
                 .map { $0.localizedName(in: english) }, "self-test results")
        distinct(ConflictSeverity.allCases.compactMap { $0.localizedKind(in: english) }, "other apps")
        distinct(FixAction.allCases.map { $0.title(in: english) }, "actions")
        distinct(FixAction.allCases.map { $0.menuTitle(in: english) }, "menu actions")
    }

    /// The words of DESIGN.md §7 and §12.
    @Test func theWords() {
        #expect(LevelPreset.brightRoom.localizedName(in: english) == "Bright room")
        #expect(LevelPreset.brightRoom.menuTitle(in: english) == "Bright Room")
        #expect(CapMode.allCases.map { $0.localizedName(in: english) } == ["Safe", "Peak"])
        #expect(MechanismPreference.allCases.map { $0.localizedName(in: english) }
                == ["Automatic", "Color table", "Compatibility mode"])
        #expect(TriggerStrategy.allCases.map { $0.localizedName(in: english) }
                == ["Tagged layer", "Metal layer", "Metal layer, refreshed", "HDR frame", "HDR video still"])
        #expect(TriggerStrategy.taggedLayer.localizedName(pixel: .black, in: english) == "Tagged layer, black")
        #expect(OLEDOverride.automatic.localizedName(detectedOLED: true, in: english) == "Automatic (OLED)")
        #expect(BatteryGuard.allCases.map { $0.menuTitle(in: english) } == ["Pause Below a Level", "Pause on Battery", "Keep Boosting"])
        #expect(LaunchBehavior.dontLaunch.localizedName(in: english) == "Don’t open Overbright")
        #expect(StatusSymbolState.attention.accessibilityLabel(in: english) == "Overbright, needs attention")
        #expect(StatusSymbolState.dimming.accessibilityValue(in: english) == "Dimmed")
        #expect(SelfTestStrategyResult.Verdict.invalidBaseline.localizedName(in: english) == "Already bright")
        #expect(ConflictSeverity.benign.localizedKind(in: english) == nil)
        let record = CalibrationRecord(outcome: .encoded, mechanism: .table, mergeFactor: 1.6, estimatedExponent: nil,
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

    /// The footer chips' labels and menus (DESIGN.md §5.9).
    @Test func footerChips() {
        let battery = GuardChipModel.battery(.belowThreshold, threshold: 20, in: english)
        #expect(battery.text == "Below 20%" && battery.compactText == "20%" && battery.accessibilityLabel == "Battery limit")
        #expect(GuardChipModel.battery(.onlyOnAdapter, threshold: 20, in: english).text == "Adapter only")
        #expect(GuardChipModel.battery(.off, threshold: 20, in: english).text == "Any charge")
        #expect(GuardChipModel.autoPause(anyRuleOn: true, in: english).text == "Auto-pause")
        #expect(GuardChipModel.autoPause(anyRuleOn: false, in: english).text == "Auto-pause · Off")
        #expect(GuardChipModel.timer(minutes: nil, remaining: nil, in: english).text == "No timer")
        #expect(GuardChipModel.timer(minutes: 30, remaining: .seconds(23 * 60), in: english).text == "Off in 23 min")
        #expect(GuardChipModel.timer(minutes: 30, remaining: .seconds(22 * 60 + 5), in: english).text == "Off in 23 min",
                "the countdown rounds up")
        let menu = GuardChipMenus.battery(current: .belowThreshold, threshold: 35, setGuard: { _ in }, setThreshold: { _ in },
                                          in: english)
        #expect(menu.count == 5)
        if case let .submenu(title, items) = menu[4] {
            #expect(title == "Battery Level")
            #expect(items.count == 5, "10, 20, 30, 35 (the current value), 50")
        } else {
            Issue.record("the last row is the Battery Level submenu")
        }
        let timer = GuardChipMenus.timer(minutes: nil, set: { _ in }, in: english)
        if case let .submenu(title, items) = timer[0] {
            #expect(title == "Turn Off After" && items.count == 5)
            let rows = items.compactMap { item -> String? in
                if case let .item(title, _, _) = item { return title }
                return nil
            }
            #expect(rows == ["Never", "15 Minutes", "30 Minutes", "1 Hour", "2 Hours"], "title case (DESIGN.md §5.9)")
        } else {
            Issue.record("the timer menu is one submenu")
        }
        #expect(GuardChipMenus.timerTitle(minutes: 1, in: english) == "1 Minute")
        #expect(GuardChipMenus.timerTitle(minutes: 45, in: english) == "45 Minutes")
        #expect(GuardChipMenus.timerTitle(minutes: 90, in: english) == "1 Hour, 30 Minutes")
    }

    /// The shortcuts' names in Settings ▸ Shortcuts and the commands they stand for in menus (DESIGN.md §4.3, §4.4,
    /// §7.6, §16).
    @Test func shortcutsAndTheirCommands() {
        let ids: [ShortcutID] = ShortcutCatalog.all.map(\.id)
        #expect(ids.compactMap { $0.localizedName(in: english) }
                == ["Turn Overbright on or off", "Brighter", "Less Bright", "Max", "Back to Standard",
                    "Dim Below Minimum On or Off", "Fill Light"])
        #expect(ids.compactMap { $0.menuTitle(in: english) }
                == ["Turn On Overbright", "Brighter", "Less Bright", "Max", "Back to Standard", "Dim All Displays",
                    "Fill Light"])
        #expect(ShortcutID.toggle.menuTitle(isActive: true, in: english) == "Turn Off Overbright")
        #expect(ShortcutID.dimToggle.menuTitle(isActive: true, in: english) == "Stop Dimming")
        #expect(ShortcutID("boost.unknown").localizedName(in: english) == nil)
        #expect(ShortcutID("boost.unknown").menuTitle(in: english) == nil)
        #expect(StepDirection.brighter.localizedName(in: english) == "Brighter")
        #expect(StepDirection.lessBright.localizedName(in: english) == "Less Bright")
        distinct(ids.compactMap { $0.localizedName(in: english) }, "shortcut names")
        for id in ids {
            for name in [id.localizedName(in: english), id.menuTitle(in: english)].compactMap({ $0 }) {
                #expect(!name.localizedCaseInsensitiveContains("Dimmer"), "\(name) (DESIGN.md §16)")
            }
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

    /// The three English footer chips fit the 304-pt footer row in their default settings, and their compact forms
    /// (glyph + value) fit with the longest settings (DESIGN.md §5.9).
    @Test func theFooterRowFits() {
        let defaults = [GuardChipModel.battery(.belowThreshold, threshold: 20, in: english),
                        GuardChipModel.autoPause(anyRuleOn: true, in: english),
                        GuardChipModel.timer(minutes: nil, remaining: nil, in: english)]
        #expect(!GuardChip.needsCompactRow(defaults), "\(GuardChip.rowWidth(of: defaults, compact: false)) pt")
        let longest = [GuardChipModel.battery(.belowThreshold, threshold: 20, in: english),
                       GuardChipModel.autoPause(anyRuleOn: false, in: english),
                       GuardChipModel.timer(minutes: 120, remaining: .seconds(119 * 60), in: english)]
        #expect(GuardChip.rowWidth(of: longest, compact: true) <= GuardChip.rowWidth,
                "\(GuardChip.rowWidth(of: longest, compact: true)) pt")
        #expect(GuardChip.rowWidth(of: longest, compact: true) < GuardChip.rowWidth(of: longest, compact: false))
    }
}
