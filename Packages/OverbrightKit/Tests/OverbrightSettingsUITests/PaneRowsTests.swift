// OverbrightSettingsUITests/PaneRowsTests.swift — every pane's rows (DESIGN.md §7.3–§7.8): which rows each pane shows for
// which displays and settings, that every row with a value has a working Reset to Default, the defaults and ranges of
// the pop-ups and sliders, the deep links the panel, the menu and the banners use, and the verdicts and fixes of the
// per-display sections.
import Foundation
import OverbrightCore
import OverbrightDesign
import OverbrightPolicy
import SwiftUI
import Testing
@testable import OverbrightSettingsUI

@MainActor @Suite struct PaneRowsTests {
    private let builtIn = DisplayFixture.Keys.builtIn
    private let oled = DisplayFixture.Keys.mpg322ux

    // MARK: Every row with a value has Reset to Default

    /// Each pane's rows are exactly its value rows and its action rows: a row that shows a value cannot lack its reset.
    @Test(arguments: [false, true])
    func everyRowIsAValueOrAnAction(rich: Bool) {
        let services = rich ? PaneValues.richServices() : OverbrightServices.preview()
        let rows = SettingsPaneCatalog.rows(services: services).map(\.id)
        let values = PaneValues.values(services).map(\.info.id)
        let actions = PaneValues.actionRows(services)
        #expect(Set(values).isDisjoint(with: actions))
        let unaccounted = Set(rows).subtracting(values).subtracting(actions)
        #expect(unaccounted.isEmpty, "rows without a value or an action: \(unaccounted)")
        #expect(Set(values).isSubset(of: rows), "values without a row: \(Set(values).subtracting(rows))")
        #expect(Set(rows).count == rows.count)                                     // ids are unique
        #expect(Set(values).count == values.count)
    }

    /// Changing any row's value shows it changed, and its Reset to Default brings back the default.
    @Test func everyValueRowResets() {
        let ids = PaneValues.values(PaneValues.richServices()).map(\.info.id)
        #expect(ids.count >= 40)
        for id in ids {
            let services = PaneValues.richServices()
            guard let value = PaneValues.values(services).first(where: { $0.info.id == id }) else {
                Issue.record("\(id) disappeared")
                continue
            }
            if !value.isDefault() {                                               // the rich setup turned it on
                value.reset()
                #expect(value.isDefault(), "\(id) after reset")
            }
            #expect(PaneValues.change(id, in: services), "no change for \(id) in the test table")
            #expect(!value.isDefault(), "\(id) still reads as default after a change")
            value.reset()
            #expect(value.isDefault(), "\(id) not back at its default after Reset to Default")
        }
    }

    /// The views, not only the lists: each value row, changed, renders in its pane with Reset to Default, and the reset
    /// that row carries returns it to its default. A row view that dropped `.settingRow(value)`, or reset another key,
    /// fails here even though `everyValueRowResets` (the lists) passes. Each pane is laid out, not drawn (the rows'
    /// bodies run either way), and the test yields between rows: one long stretch on the main actor would keep the
    /// tests that wait on it (the snapshots' app lookups land there) from seeing anything land.
    @Test func everyRenderedValueRowCarriesItsReset() async {
        for id in PaneValues.values(PaneValues.richServices()).map(\.info.id) {
            await Task.yield()
            let services = PaneValues.richServices()
            if PaneValues.values(services).first(where: { $0.info.id == id })?.isDefault() == true {
                PaneValues.change(id, in: services)                               // else the rich setup changed it
            }
            guard let value = PaneValues.values(services).first(where: { $0.info.id == id }) else {
                Issue.record("\(id) disappeared after its change")
                continue
            }
            let audit = SettingRowAudit()
            let pane = SettingsPaneCatalog.view(for: value.info.pane, services: services)
                .environment(SettingsNavigator(target: value.info.pane.rawValue))
                .environment(ResetAllController(services: services))
                .environment(\.settingRowAudit, audit)
            ChromeSnapshot.layOut(pane, size: Self.tallPane)
            guard let reset = audit.resets[id] else {
                Issue.record("\(id) is shown without Reset to Default")
                continue
            }
            #expect(!value.isDefault(), "\(id) did not change")
            reset()
            #expect(value.isDefault(), "\(id): the row's own Reset to Default left it changed")
        }
    }

    /// Fill Light's miniature never measures a real display for a simulated one: fixture IDs 1–6 are real displays'
    /// numbers on many Macs (WP14).
    @Test func theFillLightPreviewNeverMeasuresARealDisplayForASimulatedOne() throws {
        let builtIn = try #require(DisplayFixture.builtinXDRLidOpen.displays.first?.facts)
        #expect(FillLightPane.width(of: builtIn, simulated: true) == FillLightPane.fallbackDisplayWidth)
        #expect(FillLightPane.width(of: nil, simulated: false) == FillLightPane.fallbackDisplayWidth)
    }

    /// Tall enough that a pane renders every row (the rich setup's Displays pane is the longest).
    private static let tallPane = CGSize(width: PaneSnapshotTests.paneSize.width, height: 4000)

    // MARK: Which rows show

    @Test func generalShowsTheIconWarningOnlyWhileTheIconCannotBeSeen() throws {
        let services = OverbrightServices.preview()
        let app = try #require(services.app as? PreviewAppControl)
        #expect(!GeneralPane.rows(services: services).contains { $0.id == "general.iconWarning" })
        app.iconVisibility = .hiddenByUser                                         // hidden on purpose: no warning
        #expect(!GeneralPane.rows(services: services).contains { $0.id == "general.iconWarning" })
        app.iconVisibility = .notVisible
        #expect(GeneralPane.rows(services: services).first?.id == "general.iconWarning")
        #expect(GeneralPane.rows(services: services).contains { $0.id == "general.quit" })
    }

    @Test func theIconWarningNamesTheShortcutOnlyWhenOneIsRegistered() {
        let short = IconWarningRow.message(toggleKeys: "⌃⌥⌘B", namesMenuBarSetting: false)
        let long = IconWarningRow.message(toggleKeys: "⌃⌥⌘B", namesMenuBarSetting: true)
        let without = IconWarningRow.message(toggleKeys: nil, namesMenuBarSetting: false)
        #expect(short.contains("⌃⌥⌘B") && !without.contains("⌃"))
        #expect(long.hasPrefix(short) && long.count > short.count)                // the Menu Bar sentence on 26+
        #expect(MenuBarIconRow.hideMessage(toggleKeys: "⌃⌥⌘B").contains("⌃⌥⌘B"))
        #expect(!MenuBarIconRow.hideMessage(toggleKeys: nil).contains("⌃"))
    }

    @Test func aBuiltInXDRDisplayShowsEveryRowButTheType() {
        let services = TestServices.classified(.builtinXDRLidOpen)
        let ids = Set(DisplaysPane.rows(services: services).map(\.id))
        let key = builtIn.rawValue
        for field in ["extraBrightness", "level", "limit", "calibration", "autoBrightness"] {
            #expect(ids.contains("displays.\(key).\(field)"), "\(field)")
        }
        #expect(ids.contains("displays.\(key)"))                                   // the section: its verdict
        #expect(!ids.contains("displays.\(key).type"))                             // built-in: no display type
        #expect(!ids.contains("displays.\(key).method"))                           // one method: no Method row
        #expect(ids.isSuperset(of: ["displays.linkLevels", "displays.nearFullBrightness"]))
    }

    @Test func anExternalOLEDDisplayHasAType() throws {
        let services = TestServices.classified(.mpg322uxHDROn)
        let ids = Set(DisplaysPane.rows(services: services).map(\.id))
        #expect(ids.contains("displays.\(oled.rawValue).type"))
        #expect(!ids.contains("displays.\(oled.rawValue).autoBrightness"))
        let model = try #require(DisplaysPane.models(services: services).first)
        #expect(model.isOLED && model.detectedOLED && model.isExternal)
        #expect(!model.boostEnabled)                                               // OLED: opt-in (D8)
    }

    /// A Sidecar display can be neither boosted nor dimmed: its section says why and shows no controls.
    @Test func aVirtualDisplayShowsOnlyItsVerdict() throws {
        let services = TestServices.classified(.sidecar)
        let sidecar = DisplayFixture.Keys.sidecar.rawValue
        let ids = DisplaysPane.rows(services: services).map(\.id).filter { $0.contains(sidecar) }
        #expect(ids == ["displays.\(sidecar)"])
        #expect(!AdvancedPane.rows(services: services).contains { $0.id.contains(sidecar) })   // no trigger method
        let model = try #require(DisplaysPane.models(services: services).first { $0.key.rawValue == sidecar })
        #expect(VerdictText.make(model.verdict, advisories: [], lastGrant: nil).badge == VerdictText.make(.virtualDisplay, advisories: [], lastGrant: nil).badge)
    }

    /// An SDR external can dim: the level row shows, the boost rows do not.
    @Test func anSDRExternalCanOnlyDim() throws {
        let services = TestServices.classified(.mpg322uxHDROff)
        let key = oled.rawValue
        let ids = Set(DisplaysPane.rows(services: services).map(\.id))
        #expect(ids.isSuperset(of: ["displays.\(key).level", "displays.\(key).type"]))
        #expect(ids.isDisjoint(with: ["displays.\(key).extraBrightness", "displays.\(key).limit", "displays.\(key).calibration"]))
        let model = try #require(DisplaysPane.models(services: services).first)
        #expect(model.verdict == .turnOnHDR)
        let text = VerdictText.make(model.verdict, advisories: [], lastGrant: nil)
        #expect(text.fix == .openSystemSettings)
        guard case .unavailable(let reason) = model.boostHalf(oledIdleMinutes: 5) else {
            Issue.record("the boost half of a display with HDR off is usable")
            return
        }
        #expect(reason == text.sentence)
    }

    @Test func automationsShowTheBatteryLevelOnlyBelowALevel() {
        let services = OverbrightServices.preview()
        #expect(AutomationsPane.rows(services: services).contains { $0.id == "automations.batteryThreshold" })
        services.settings[AutomationSettings.batteryGuard] = .onlyOnAdapter
        #expect(!AutomationsPane.rows(services: services).contains { $0.id == "automations.batteryThreshold" })
        #expect(!AutomationsPane.values(services: services).contains { $0.info.id == "automations.batteryThreshold" })
    }

    @Test func automationsShowTheHoursOnlyWhileTheScheduleIsOn() {
        let services = OverbrightServices.preview()
        let hours: Set = ["automations.scheduleFrom", "automations.scheduleTo"]
        #expect(Set(AutomationsPane.rows(services: services).map(\.id)).isDisjoint(with: hours))
        services.settings[AutomationSettings.schedule] = ScheduleEditing.defaultWindow
        #expect(Set(AutomationsPane.rows(services: services).map(\.id)).isSuperset(of: hours))
    }

    /// The OLED idle pause shows only when an OLED display is known: connected, or set to OLED by the user.
    @Test func automationsShowTheOLEDIdlePauseOnlyWithAnOLEDDisplay() {
        let builtInOnly = OverbrightServices.preview()
        #expect(!AutomationsPane.knowsOLED(builtInOnly))
        #expect(AutomationsPane.knowsOLED(OverbrightServices.preview(fixture: .mpg322uxHDROn)))
        DisplayPreferencesEditor(settings: builtInOnly.settings).update(oled, name: "MPG") { $0.oled = .oled }
        #expect(AutomationsPane.knowsOLED(builtInOnly))                              // remembered while away
        builtInOnly.settings.reset(DisplaySettings.perDisplay)
        DisplayPreferencesEditor(settings: builtInOnly.settings).update(builtIn, name: "Built-in") { $0.oled = .oled }
        #expect(AutomationsPane.knowsOLED(builtInOnly))                              // the user's override counts
    }

    // MARK: Defaults and ranges (ARCHITECTURE.md §3.8, DESIGN.md §7)

    @Test func popUpsOfferTheDesignsChoices() {
        #expect(PaneFormat.autoOffMinutes == [nil, 5, 10, 15, 20, 30, 45, 60, 90, 120])
        #expect(PaneFormat.batteryThresholds == Array(stride(from: 5, through: 95, by: 5)))
        #expect(PaneFormat.batteryThresholds.contains(AutomationSettings.batteryThreshold.defaultValue))
        #expect(PaneFormat.oledIdleMinutes == [1, 2, 5, 10, 15, 30])
        #expect(PaneFormat.oledIdleMinutes.contains(AutomationSettings.oledIdleMinutes.defaultValue))
        #expect(ShortcutsPane.order == [.toggle, .brighter, .lessBright, .max, .dimToggle, .standard, .fillLight])
        #expect(Set(ShortcutsPane.order) == Set(ShortcutCatalog.all.map(\.id)))
    }

    @Test func durationsAreSpelledOutInTheLocale() {
        let english = Locale(identifier: "en_US")
        #expect(!PaneFormat.autoOff(nil).isEmpty && PaneFormat.autoOff(nil, locale: english) != PaneFormat.autoOff(5, locale: english))
        #expect(PaneFormat.autoOff(30, locale: english) == "30 minutes")
        #expect(PaneFormat.duration(minutes: 5, locale: english) == "5 minutes")
        #expect(PaneFormat.duration(minutes: 60, locale: english) == "1 hour")
        #expect(PaneFormat.duration(minutes: 90, locale: english) == "1.5 hours")
        #expect(PaneFormat.duration(minutes: 120, locale: english) == "2 hours")
        #expect(PaneFormat.percent(20, locale: english) == "20%")
        #expect(PaneFormat.duration(minutes: 90, locale: Locale(identifier: "ru_RU")).contains("1,5"))
    }

    @Test func fillLightRangesAndWarmthInKelvin() {
        #expect(FillLightPane.widthRange == 16...120 && FillLightPane.widthRange.contains(FillLightSettings.width.defaultValue))
        #expect(FillLightPane.brightnessRange == 0.2...1)
        #expect(PaneFormat.kelvin(warmth: 0) == 6500 && PaneFormat.kelvin(warmth: 1) == 3000)
        #expect(abs(PaneFormat.kelvin(warmth: FillLightSettings.warmth.defaultValue) - 5100) < 0.5)   // DESIGN.md §7.7
        #expect(abs(FillLightPane.warmthStep * (PaneFormat.coolKelvin - PaneFormat.warmKelvin) - 100) < 1e-9)
        #expect(FillLightWarmthRow.snapped(0.401) == FillLightSettings.warmth.defaultValue)   // back on the default
        #expect(abs(PaneFormat.kelvin(warmth: FillLightWarmthRow.snapped(0.123)) - 6100) < 1e-9)   // 6,069.5 K → 6,100 K
        let warm = FillLightPreview.components(kelvin: 3000), cool = FillLightPreview.components(kelvin: 6500)
        #expect(warm.0 == 1 && warm.2 < cool.2)                                    // warmer = less blue
        #expect(FillLightPane.defaultDisplay(DisplayFixture.russianNames.displays.map(\.facts)) == builtIn)
        #expect(FillLightPane.defaultDisplay(DisplayFixture.mpg322uxHDROn.displays.map(\.facts)) == oled)
    }

    /// A minute of the day survives the time picker in any time zone; the hours exist only while the schedule is on.
    @Test func scheduleTimesRoundTripThroughThePickers() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .gmt
        for minute in [0, 480, 1199, 1439] {
            #expect(ScheduleEditing.minuteOfDay(ScheduleEditing.date(minuteOfDay: minute, calendar: calendar), calendar: calendar) == minute)
        }
        #expect(ScheduleEditing.setting(start: 600, in: nil) == nil)
        #expect(ScheduleEditing.setting(end: 60, in: ScheduleEditing.defaultWindow) == ScheduleWindow(startMinute: 480, endMinute: 60))
    }

    // MARK: Deep links (PanelUI's `SettingsLinks`, the banners and Help)

    @Test func everyDeepLinkPointsAtARowThatExists() {
        let services = TestServices.classified(.builtinXDRLidOpen)
        let rows = Set(SettingsPaneCatalog.rows(services: services).map(\.id))
        let links = ["displays#nearFullBrightness", "automations#power", "automations#timer", "automations#apps",
                     "automations#pausedApps", "automations#schedule", "advanced#selfTest", "general#quit",
                     "displays#\(builtIn.rawValue)", "displays#\(builtIn.rawValue).limit", "advanced#resetAll"]
        for link in links {
            let parsed = SettingsNavigator.parse(link)
            #expect(parsed.row.map(rows.contains) == true, "\(link)")
        }
    }

    // MARK: Display sections

    @Test func theSectionModelFollowsTheVerdictAndTheCapMode() throws {
        let services = TestServices.classified(.builtinXDRLidOpen)
        var model = try #require(DisplaysPane.models(services: services).first)
        guard case .supported(let safe?, let peak) = model.verdict else {
            Issue.record("the built-in XDR display is not supported: \(model.verdict)")
            return
        }
        #expect(model.top == safe && model.peakTop == peak && peak > safe)
        #expect(model.presets.last == .max)
        #expect(model.boostEnabled)                                                // built-in XDR: on by default
        #expect(model.boostHalf(oledIdleMinutes: 5) == .inactive)                  // Overbright is off
        DisplayPreferencesEditor(settings: services.settings).update(builtIn, name: "Built-in") { $0.capMode = .peak }
        model = try #require(DisplaysPane.models(services: services).first)
        #expect(model.top == peak)
        DisplayPreferencesEditor(settings: services.settings).update(builtIn, name: "Built-in") { $0.boostEnabled = false }
        model = try #require(DisplaysPane.models(services: services).first)
        #expect(model.boostHalf(oledIdleMinutes: 5) == .switchedOff)
    }

    /// The Limit footnote is the display's own Safe sentence, then what Peak does.
    @Test func theLimitFootnoteStartsWithTheClassSafeSentence() throws {
        let xdr = try #require(DisplaysPane.models(services: TestServices.classified(.builtinXDRLidOpen)).first)
        let oledModel = try #require(DisplaysPane.models(services: TestServices.classified(.mpg322uxHDROn)).first)
        #expect(xdr.safeSentence != oledModel.safeSentence)
        #expect(oledModel.safeSentence == SafeLimitText(panelClass: .oledExternal, isOLED: true, safeTop: nil).sentence())
    }

    /// Where Max is at most ×1.3 (an OLED in Safe), the value text and the spoken value say "small gain on this
    /// display"; the dim half and other displays never do.
    @Test func smallGainIsSaidInTextAndSpeech() throws {
        let oledModel = try #require(DisplaysPane.models(services: TestServices.classified(.mpg322uxHDROn)).first)
        let xdr = try #require(DisplaysPane.models(services: TestServices.classified(.builtinXDRLidOpen)).first)
        let max = LevelPreset.max.position, dimmed = LevelPosition(-0.5)
        #expect(oledModel.hasSmallGain && !xdr.hasSmallGain)
        #expect(oledModel.valueText(at: max).contains(ValueText.smallGain()))
        #expect(oledModel.spokenValue(at: max).contains(ValueText.smallGain()))
        #expect(!oledModel.spokenValue(at: dimmed).contains(ValueText.smallGain()))
        #expect(!xdr.spokenValue(at: max).contains(ValueText.smallGain()))
        #expect(xdr.spokenValue(at: max) == ValueText.forLevel(max, top: xdr.top, presets: xdr.presets, isEstimate: xdr.readout.isEstimate).accessibilityText)
    }

    /// A calibration record applies while the build and the method match and the potential is within 5 %; without a
    /// reading it is not called stale for the potential alone.
    @Test func calibrationValidity() {
        let machine = DisplayFixture.ownerMachine
        let record = FakeCalibrationSession.record(.encoded)
        #expect(DisplaySectionModel.isValid(record, mechanism: .table, machine: machine, potential: 16))
        #expect(DisplaySectionModel.isValid(record, mechanism: .table, machine: machine, potential: 16.7))
        #expect(!DisplaySectionModel.isValid(record, mechanism: .table, machine: machine, potential: 17))
        #expect(DisplaySectionModel.isValid(record, mechanism: .table, machine: machine, potential: nil))
        var updated = machine
        updated.osBuild = "27A1"
        #expect(!DisplaySectionModel.isValid(record, mechanism: .table, machine: updated, potential: 16))
        #expect(!DisplaySectionModel.isValid(nil, mechanism: .table, machine: machine, potential: 16))
    }

    /// Editing a display remembers its name (for "Not connected") and an entry back at every default is removed.
    @Test func theEditorRemembersNamesAndDropsDefaultEntries() {
        let services = OverbrightServices.preview()
        let editor = DisplayPreferencesEditor(settings: services.settings)
        editor.update(oled, name: "MPG322UX OLED") { $0.capMode = .peak }
        #expect(editor.preferences(of: oled).lastKnownName == "MPG322UX OLED")
        let away = DisplaysPane.remembered(services: services)                     // the MSI is not connected here
        #expect(away.map(\.key) == [oled] && away.first?.name == "MPG322UX OLED")
        #expect(DisplaysPane.rows(services: services).contains { $0.id == "displays.remembered.\(oled.rawValue)" })
        editor.update(oled, name: "MPG322UX OLED") { $0.capMode = .safe }
        #expect(services.settings[DisplaySettings.perDisplay][oled] == nil)
        editor.update(oled, name: nil) { $0.capMode = .peak }
        editor.forget(oled)
        #expect(services.settings.isDefault(DisplaySettings.perDisplay))
    }

    /// The trigger method pop-up disables the tagged layer before macOS 26.
    @Test func triggerMethodsNeedTheirMacOS() {
        var old = DisplayFixture.ownerMachine
        old.osMajor = 15
        #expect(!TriggerMethodSection.isAvailable(.taggedLayer, on: old))
        #expect(TriggerMethodSection.isAvailable(.taggedLayer, on: DisplayFixture.ownerMachine))
        #expect(TriggerStrategy.allCases.filter { $0 != .taggedLayer }.allSatisfy { TriggerMethodSection.isAvailable($0, on: old) })
    }

    /// The other apps list: kinds S1–S3 only, Always continue for color apps and "may change" apps.
    @Test func otherAppsListTheirKindAndOfferContinuingWhereAllowed() {
        let booster = ConflictingApp(entryID: "S1-example", severity: .booster, bundleID: "com.example.booster",
                                     processID: 10, displayName: "Booster")
        let colors = ConflictingApp(entryID: "S2-example", severity: .gammaWriter, bundleID: "com.example.colors",
                                    processID: 11, displayName: "Colors")
        let benign = ConflictingApp(entryID: "S4-example", severity: .benign, bundleID: "com.example.benign",
                                    processID: 12, displayName: "Benign")
        #expect(OtherAppsSection.apps([booster, colors, benign, colors]).map(\.entryID) == ["S1-example", "S2-example"])
        #expect(!OtherAppsSection.offersAlwaysContinue(booster) && OtherAppsSection.offersAlwaysContinue(colors))
    }
}
