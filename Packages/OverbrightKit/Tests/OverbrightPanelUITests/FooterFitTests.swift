// OverbrightPanelUITests/FooterFitTests.swift — the footer’s three guard chips fit one 304-pt row (DESIGN.md §5.9,
// §16; ARCHITECTURE.md §8.8 width rule `chip`), and when a long translation would not fit, every chip drops to glyph +
// value and the row still fits. Measured on the footer row the panel draws (its glyphs as wide as they draw:
// `battery.25percent` is 21 pt at 12 pt, not 12), for the widest settings (pause below a level, every rule off, a running
// 1 h 30 min timer), in English and the pseudo-long locale, and in every language Overbright ships (WP15), where the
// default row must show its words in full. Also: what each chip says for its settings, what VoiceOver hears (the
// chip's name as the label, its state as the value, in every row style), and that its menu edits exactly that setting.
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI
import Testing
@testable import OverbrightPanelUI

@MainActor @Suite struct FooterFitTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// The widest chips: "Below 20%", "Auto-pause · Off", "Off in 1 hr, 30 min" (the full row does not fit even in
    /// English; glyph + value does).
    private func widestChips() -> [FooterChip] {
        let settings = SettingsStore(defaults: InMemoryDefaults())
        settings[AutomationSettings.pauseForFullScreenVideo] = false
        settings[AutomationSettings.pauseForListedApps] = false
        settings[AutomationSettings.autoOffMinutes] = 90
        return FooterChips.chips(settings: settings, hasBattery: true, autoOffAt: now.addingTimeInterval(90 * 60),
                                 now: now, editApps: {})
    }

    private func lengthened(_ chips: [FooterChip]) -> [FooterChip] {
        chips.map { chip in
            FooterChip(kind: chip.kind,
                       model: GuardChipModel(symbol: chip.model.symbol, text: PseudoLocale.lengthen(chip.model.text),
                                             accessibilityLabel: chip.model.accessibilityLabel),
                       compact: GuardChipModel(symbol: chip.compact.symbol, text: PseudoLocale.lengthen(chip.compact.text),
                                               accessibilityLabel: chip.compact.accessibilityLabel),
                       menu: chip.menu)
        }
    }

    /// The width of the row the footer draws in `style` (measured, glyphs included).
    private func rowWidth(_ chips: [FooterChip], _ style: PanelFooter.Style) -> CGFloat {
        FitMeasure.idealWidth(PanelFooter(chips: chips, focus: nil).row(style))
    }

    /// The default settings: "Below 20%", "Auto-pause", "No timer".
    private func defaultChips() -> [FooterChip] {
        FooterChips.chips(settings: SettingsStore(defaults: InMemoryDefaults()), hasBattery: true, autoOffAt: nil, now: now,
                          editApps: {})
    }

    @Test func theDefaultRowFitsInFullInEnglish() {
        let width = rowWidth(defaultChips(), .full)
        #expect(width > 0 && width <= PanelLayout.footerWidth, "the default footer row is \(width) pt")
        // "20 %" alone would read as a battery level: the default row never drops to glyph + value in English.
        let footer = PanelFooter(chips: defaultChips(), focus: nil)
        let drawn = FitMeasure.width(footer, offered: PanelLayout.footerWidth)
        #expect(abs(drawn - width) < 1, "drawn \(drawn) pt, the full row \(width) pt")
    }

    /// Design's row budget counts the glyphs as they draw, and agrees with the rendered row (C-PANEL-3).
    @Test func theRowBudgetMeasuresTheGlyphs() {
        #expect(GuardChip.glyphWidth(.battery25Percent) > GlyphSize.chip + 4)      // 21 pt, not 12
        for chips in [defaultChips(), widestChips()] {
            let budget = GuardChip.rowWidth(of: chips.map(\.model), compact: false)
            let drawn = rowWidth(chips, .full)
            #expect(abs(budget - drawn) <= 2, "budget \(budget) pt, drawn \(drawn) pt")
        }
    }

    @Test func everyRowFitsInFullOrAsGlyphAndValue() {
        let rows = ["default": defaultChips(), "widest": widestChips(),
                    "default pseudo-long": lengthened(defaultChips()), "widest pseudo-long": lengthened(widestChips())]
        for (name, chips) in rows {
            let full = rowWidth(chips, .full)
            let compact = rowWidth(chips, .compact)
            #expect(full <= PanelLayout.footerWidth || compact <= PanelLayout.footerWidth,
                    "\(name): neither the full row (\(full) pt) nor glyph + value (\(compact) pt) fits")
            #expect(compact <= full, "\(name)")
        }
    }

    @Test func theRenderedFooterNeverLeavesItsRow() {
        for chips in [widestChips(), lengthened(widestChips()), lengthened(lengthened(widestChips()))] {
            let footer = PanelFooter(chips: chips, focus: nil)
            #expect(FitMeasure.width(footer, offered: PanelLayout.footerWidth) <= PanelLayout.footerWidth)
            #expect(FitMeasure.idealWidth(footer.row(.glyphs)) <= PanelLayout.footerWidth)
        }
    }

    // MARK: Every language (WP15)

    /// The footer rows in `code`'s words: the default settings, each other battery rule beside the default chips, and
    /// the widest settings ("Below 20 %", "Auto-pause · Off", "Off in 1 h 30 min").
    private func rows(in code: String) throws -> [(name: String, chips: [FooterChip])] {
        let words = try #require(PanelWords(code), "\(code): no PanelUI table")
        let percent = words.percent(20)
        let duration = words.duration(minutes: 90)
        func localized(_ chips: [FooterChip], battery: String = words.below(percent),
                       widest: Bool = false) -> [FooterChip] {
            chips.map { chip in
                let (text, compact): (String, String) = switch chip.kind {
                case .battery: (battery, battery == words.below(percent) ? percent : "")
                case .autoPause: widest ? (words.autoPauseOff, words.off) : (words.autoPause, "")
                case .timer: widest ? (words.offIn(duration), duration) : (words.noTimer, "")
                }
                let model = GuardChipModel(symbol: chip.model.symbol, text: text, accessibilityLabel: text)
                let small = GuardChipModel(symbol: chip.compact.symbol, text: compact, accessibilityLabel: text)
                return FooterChip(kind: chip.kind, model: model, compact: small, menu: chip.menu)
            }
        }
        return [("default", localized(defaultChips())),
                ("adapter only", localized(defaultChips(), battery: words.adapterOnly)),
                ("any charge", localized(defaultChips(), battery: words.anyCharge)),
                ("widest", localized(widestChips(), widest: true))]
    }

    /// The default row shows its words in every language; every other row shows them or drops to glyph + value, and the
    /// footer as drawn never leaves its row.
    @Test(arguments: ShippedLanguages.codes)
    func everyRowFitsInEveryLanguage(_ code: String) throws {
        let rows = try rows(in: code)
        let defaultRow = try #require(rows.first { $0.name == "default" })
        let width = rowWidth(defaultRow.chips, .full)
        #expect(width > 0 && width <= PanelLayout.footerWidth, "\(code): the default footer row is \(width) pt")
        for (name, chips) in rows {
            let full = rowWidth(chips, .full)
            let compact = rowWidth(chips, .compact)
            #expect(full <= PanelLayout.footerWidth || compact <= PanelLayout.footerWidth,
                    "\(code), \(name): neither the full row (\(full) pt) nor glyph + value (\(compact) pt) fits")
            let footer = PanelFooter(chips: chips, focus: nil)
            let drawn = FitMeasure.width(footer, offered: PanelLayout.footerWidth)
            #expect(drawn <= PanelLayout.footerWidth, "\(code), \(name): \(drawn) pt")
        }
    }

    // MARK: Words and menus

    @Test func eachChipShowsItsSettingNeverALiveValue() throws {
        let settings = SettingsStore(defaults: InMemoryDefaults())
        func texts(autoOffAt: Date? = nil, hasBattery: Bool = true) -> [FooterChip.Kind: String] {
            Dictionary(uniqueKeysWithValues: FooterChips.chips(settings: settings, hasBattery: hasBattery, autoOffAt: autoOffAt,
                                                               now: now, editApps: {}).map { ($0.kind, $0.model.text) })
        }
        let percent = (0.2).formatted(.percent)
        let below = try #require(texts()[.battery])
        #expect(below.contains(percent))                                       // "Below 20%": the setting
        #expect(texts(hasBattery: false)[.battery] == nil)                     // no battery, no chip
        settings[AutomationSettings.batteryGuard] = .onlyOnAdapter
        let adapterOnly = try #require(texts()[.battery])
        #expect(adapterOnly != below && !adapterOnly.contains(percent))
        settings[AutomationSettings.batteryGuard] = .off
        #expect(try #require(texts()[.battery]) != adapterOnly)
        let autoPauseOn = try #require(texts()[.autoPause])
        settings[AutomationSettings.pauseForFullScreenVideo] = false
        settings[AutomationSettings.pauseForListedApps] = false
        #expect(try #require(texts()[.autoPause]) != autoPauseOn)
        let noTimer = try #require(texts()[.timer])
        settings[AutomationSettings.autoOffMinutes] = 30
        let set = try #require(texts()[.timer])
        let running = try #require(texts(autoOffAt: now.addingTimeInterval(23 * 60))[.timer])
        #expect(Set([noTimer, set, running]).count == 3)
        #expect(running.contains("23"))
    }

    /// VoiceOver hears each chip's name, then its state, once: "Battery limit, Below 20 %", "Auto-pause, On",
    /// "Timer, No timer"; the same in the compact and glyph-only rows (C-PANEL-17).
    @Test func voiceOverHearsTheNameThenTheState() throws {
        let settings = SettingsStore(defaults: InMemoryDefaults())
        settings[AutomationSettings.autoOffMinutes] = 30
        let chips = FooterChips.chips(settings: settings, hasBattery: true, autoOffAt: nil, now: now, editApps: {})
        let names = chips.map(\.model.accessibilityLabel)
        #expect(names == [FooterText.batteryLimit, FooterText.autoPause, FooterText.timerLabel])
        let battery = try #require(chips.first)
        #expect(battery.model.accessibilityValue == battery.model.text)            // "Below 20 %", not twice
        #expect(chips[1].model.accessibilityValue == FooterText.on)
        #expect(chips[2].model.accessibilityValue == chips[2].model.text)          // "Off after 30 min", in full
        for chip in chips {
            for style in PanelFooter.Style.allCases {
                let model = PanelFooter.model(of: chip, style)
                #expect(model.accessibilityLabel == chip.model.accessibilityLabel, "\(chip.kind) \(style)")
                #expect(model.accessibilityValue == chip.model.accessibilityValue, "\(chip.kind) \(style)")
                #expect(model.accessibilityValue.map { !$0.isEmpty && $0 != model.accessibilityLabel } == true)
            }
        }
    }

    @Test func theMenusEditTheAutomationSettings() throws {
        let settings = SettingsStore(defaults: InMemoryDefaults())
        var editedApps = 0
        let chips = FooterChips.chips(settings: settings, hasBattery: true, autoOffAt: nil, now: now,
                                      editApps: { editedApps += 1 })
        let battery = try #require(chips.first { $0.kind == .battery })
        try run(battery.menu, at: [1])                                         // Pause on Battery
        #expect(settings[AutomationSettings.batteryGuard] == .onlyOnAdapter)
        try run(battery.menu, at: [4, 3])                                      // Battery Level ▸ 50 %
        #expect(settings[AutomationSettings.batteryThreshold] == 50)
        #expect(settings[AutomationSettings.batteryGuard] == .belowThreshold)
        let autoPause = try #require(chips.first { $0.kind == .autoPause })
        try run(autoPause.menu, at: [1])                                       // Every Full-Screen App
        #expect(settings[AutomationSettings.pauseForAllFullScreen])
        try run(autoPause.menu, at: [4])                                       // Edit Apps…
        #expect(editedApps == 1)
        let timer = try #require(chips.first { $0.kind == .timer })
        try run(timer.menu, at: [0, 3])                                        // Turn Off After ▸ 1 Hour
        #expect(settings[AutomationSettings.autoOffMinutes] == 60)
        settings[AutomationSettings.batteryThreshold] = 35                    // a value only Settings offers
        let levels = try #require(FooterChips.chips(settings: settings, hasBattery: true, autoOffAt: nil, now: now,
                                                    editApps: {}).first?.menu.last)
        guard case let .submenu(_, items) = levels else { Issue.record("no Battery Level submenu"); return }
        #expect(items.count == FooterChips.batteryLevels.count + 1)            // the current value is inserted, checked
    }

    /// Runs the menu row at `path` (submenu indices).
    private func run(_ menu: [GuardChipMenuItem], at path: [Int]) throws {
        var items = menu
        for (depth, index) in path.enumerated() {
            let item = try #require(items.indices.contains(index) ? items[index] : nil)
            switch item {
            case .item(_, _, let perform) where depth == path.count - 1: perform()
            case .submenu(_, let children): items = children
            default: Issue.record("no row at \(path)")
            }
        }
    }
}
