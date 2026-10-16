// OverbrightAppShellTests/HUDFitTests.swift — the HUD's text fits (DESIGN.md §6, §16: HUD text ≤ 200 pt; ARCHITECTURE.md
// §8.8 width rule `hud`): every value and reason of §12.9 in the HUD's type, in English and the pseudo-long locale
// (+40 %), plus whatever Design's `HUDText` makes for the gallery's HUD states; in every language Overbright ships
// (WP15) the values, the reasons and the Keep-this-level prompt are measured too; the HUD itself is
// 280 × 56 pt whatever it says, and its bar draws the level. Measured in hosting views without a window.
import AppKit
import OverbrightCore
import OverbrightDesign
import OverbrightPanelUI
import OverbrightPolicy
import SwiftUI
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct HUDFitTests {
    /// DESIGN.md §12.9.
    static let values = ["Bright room · ×1.29", "×1.42", "Standard", "Dimmed · 25 %", "Off", "Sunlight · ≈ ×2.04"]
    static let reasons = ["Preparing…", "Paused until 14:20", "Off for this Focus", "Paused: battery below 20 %",
                          "Paused: on battery", "Paused: Low Power Mode", "Paused: Mac is hot", "Limited: Mac is warm",
                          "Paused: outside set hours", "Off: timer ended", "Extra brightness is back"]

    /// DESIGN.md §2.2 `hudValue` and `hudLabel`.
    static let valueFont = Font.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit()
    static let labelFont = Font.system(size: 11)

    /// The pseudo-long locale (+40 %), as in PanelUI's fit tests.
    static func lengthen(_ text: String) -> String {
        let letters = text.filter(\.isLetter).count
        return text + String(repeating: "é", count: Int((Double(max(letters, 1)) * 0.4).rounded(.up)))
    }

    private func width(_ text: String, _ font: Font) -> CGFloat {
        NSHostingView(rootView: Text(verbatim: text).font(font).lineLimit(1).fixedSize()).fittingSize.width
    }

    /// The gallery's HUD texts in Design's words (empty until WP9's copy lands).
    static var builderTexts: [HUDText] {
        ScriptedStatuses.hudNames.compactMap { name -> HUDText? in
            guard let status = ScriptedStatuses.status(named: name), let change = status.lastChange else { return nil }
            return HUDText.make(change, status: status)
        }
    }

    @Test func valuesAndReasonsFitInEnglishAndPseudoLong() {
        var failures: [String] = []
        let values = Self.values + Self.builderTexts.compactMap(\.value)
        let reasons = Self.reasons + Self.builderTexts.compactMap(\.reason)
        for text in values + values.map(Self.lengthen) where width(text, Self.valueFont) > HUDView.textWidth {
            failures.append("value «\(text)» \(width(text, Self.valueFont)) pt")
        }
        for text in reasons + reasons.map(Self.lengthen) where width(text, Self.labelFont) > HUDView.textWidth {
            failures.append("reason «\(text)» \(width(text, Self.labelFont)) pt")
        }
        #expect(failures.isEmpty, "HUD text wider than \(HUDView.textWidth) pt: \(failures)")
    }

    // MARK: Every language (WP15)

    /// Every language Overbright ships (Design's catalog, English included).
    nonisolated static let languages = CopyLanguage.available

    /// The HUD's values and reason lines in `language`: §12.9's values as numbers and every preset, each guard's line,
    /// the change lines (Preparing…, back, timer ended) and the gallery's HUD states.
    static func texts(in language: CopyLanguage) -> (values: [String], reasons: [String]) {
        func value(_ state: ReadoutValues.State, _ gain: Double = 1, preset: LevelPreset? = nil, estimate: Bool = false,
                   dim: Int? = nil) -> String {
            ValueText.make(ReadoutValues(state: state, appliedGain: gain, requestedGain: nil, nits: nil, preset: preset,
                                         isEstimate: estimate, dimPercent: dim), in: language).text
        }
        let values = [value(.boost, 1.29, preset: .brightRoom), value(.boost, 1.29, preset: .brightRoom, estimate: true),
                      value(.boost, 1.42), value(.standard), value(.dim, 0.25, dim: 25), value(.off),
                      value(.boost, 2.04, preset: .sunlight, estimate: true),
                      value(.boost, 1.12, preset: .indoor, estimate: true),
                      value(.boost, 2.6, preset: .max, estimate: true)]
        let reasons: [LimitReason] = [.userPaused(until: Date(timeIntervalSinceReferenceDate: 800_000_000)), .focusOff,
                                      .battery(percent: 12, threshold: 20), .onBattery, .lowPowerMode, .thermalCritical,
                                      .thermalSerious, .outsideSchedule]
        let status = BoostStatus(isOn: true, isReady: true, pausedUntil: nil, autoOffAt: nil, displays: [], banner: nil,
                                 symbol: .dimming)
        let changes = [LevelChange.Kind.preparing, .automationResumed, .timerEnded].compactMap { kind in
            HUDText.make(LevelChange(sequence: 1, kind: kind, source: .shortcut, display: nil), status: status, on: nil,
                         in: language)?.reason
        }
        let gallery = ScriptedStatuses.hudNames.compactMap { name -> HUDText? in
            guard let status = ScriptedStatuses.status(named: name), let change = status.lastChange else { return nil }
            return HUDText.make(change, status: status, on: nil, in: language)
        }
        let lines = reasons.compactMap { HUDText.reasonLine(for: $0, in: language) }
        return (values + gallery.compactMap(\.value), lines + changes + gallery.compactMap(\.reason))
    }

    @Test(arguments: languages)
    func valuesAndReasonsFitInEveryLanguage(_ code: String) {
        let language = CopyLanguage.named(code) ?? .english()
        let (values, reasons) = Self.texts(in: language)
        #expect(values.count >= 9 && reasons.count >= 11, "\(code)")
        var failures: [String] = []
        for text in values where width(text, Self.valueFont) > HUDView.textWidth {
            failures.append("value «\(text)» \(width(text, Self.valueFont)) pt")
        }
        for text in reasons where width(text, Self.labelFont) > HUDView.textWidth {
            failures.append("reason «\(text)» \(width(text, Self.labelFont)) pt")
        }
        #expect(failures.isEmpty, "\(code): HUD text wider than \(HUDView.textWidth) pt: \(failures)")
    }

    /// The Keep-this-level prompt (DESIGN.md §6, 280 pt wide): its title, its countdown and its two buttons each fit
    /// between the prompt's insets, in the shell's words and in Design's.
    @Test(arguments: languages)
    func theKeepLevelPromptFitsInEveryLanguage(_ code: String) {
        let bundle = Bundle.module.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .module
        let (locale, language) = (Locale(identifier: code), CopyLanguage.named(code) ?? .english())
        let titles = [String(localized: "Keep this level?", table: "StatusMenu", bundle: bundle, locale: locale),
                      ConfirmationText.keepLevelTitle(in: language)]
        let countdowns = [String(localized: "Going back in \(10) s", table: "StatusMenu", bundle: bundle,
                                 locale: locale),
                          ConfirmationText.goingBack(seconds: 10, in: language)]
        let buttons = [(String(localized: "Go Back", table: "StatusMenu", bundle: bundle, locale: locale),
                        String(localized: "Keep", table: "StatusMenu", bundle: bundle, locale: locale)),
                       (ConfirmationText.goBack(in: language), ConfirmationText.keep(in: language))]
        let room = HUDPlacement.promptSize.width - 2 * Space.l
        for title in titles {
            #expect(width(title, .headline) <= room, "\(code): «\(title)» \(width(title, .headline)) pt")
        }
        for countdown in countdowns {
            let measured = width(countdown, .callout.monospacedDigit())
            #expect(measured <= room, "\(code): «\(countdown)» \(measured) pt")
        }
        for (goBack, keep) in buttons {
            let row = NSHostingView(rootView: HStack(spacing: Space.m) {
                Button(action: {}) { Text(verbatim: goBack) }
                Button(action: {}) { Text(verbatim: keep) }
            }.fixedSize()).fittingSize.width
            #expect(row <= room, "\(code): «\(goBack)» «\(keep)» \(row) pt")
        }
    }

    @Test func theHUDKeepsItsSizeWhateverItSays() {
        let long = String(repeating: "Extra brightness is back ", count: 4)
        for text in [HUDText(symbol: .sunMaxFill, displayName: "Built-in Retina Display", value: "Bright room · ×1.29",
                             reason: nil, announcement: "Bright room, 1.29 times"),
                     HUDText(symbol: .timer, displayName: nil, value: nil, reason: long, announcement: long)] {
            let size = NSHostingView(rootView: HUDView(text: text, level: LevelPosition(0.5), isBoosting: true)
                .overbrightThemeRoot()).fittingSize
            #expect(size == HUDPlacement.size)
        }
    }

    @Test func theHUDGoesAboveTheDockOnTheDisplayThatChanged() {
        let main = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let visible = CGRect(x: 0, y: 70, width: 1512, height: 880)
        let other = CGRect(x: 1512, y: 0, width: 2560, height: 1440)
        let screens: [(id: CGDirectDisplayID?, frame: CGRect, visibleFrame: CGRect)] = [(1, main, visible), (2, other, other)]
        #expect(HUDPlacement.visibleFrame(for: 2, pointer: CGPoint(x: 10, y: 10), screens: screens, main: visible) == other)
        #expect(HUDPlacement.visibleFrame(for: nil, pointer: CGPoint(x: 2000, y: 10), screens: screens, main: visible)
            == other)                                                   // every display: the one under the pointer
        #expect(HUDPlacement.visibleFrame(for: 9, pointer: CGPoint(x: -50, y: -50), screens: screens, main: visible)
            == visible)
        let frame = HUDPlacement.frame(size: HUDPlacement.size, visibleFrame: visible)
        #expect(frame.midX == visible.midX && frame.minY == visible.minY + 64 && frame.size == HUDPlacement.size)
    }

    @Test func theValueKeepsItsWidthBesideTheBar() {
        // The longest English value next to a display name still shows whole (the bar has its own line).
        let text = HUDText(symbol: .sunMaxFill, displayName: "Built-in Retina Display", value: "Sunlight · ≈ ×2.04",
                           reason: nil, announcement: "")
        let full = NSHostingView(rootView: Text(verbatim: "Sunlight · ≈ ×2.04").font(Self.valueFont).fixedSize())
            .fittingSize.width
        #expect(full <= HUDView.textWidth)
        let hud = NSHostingView(rootView: HUDView(text: text, level: LevelPosition(0.75), isBoosting: true)
            .overbrightThemeRoot())
        #expect(hud.fittingSize == HUDPlacement.size)
    }

    @Test func theBoostFillIsWarmOnlyWithExtraLight() throws {
        let boosting = try #require(ScriptedStatuses.status(named: "hud-boost"))
        let dimmed = try #require(ScriptedStatuses.status(named: "hud-dim"))
        let key = DisplayFixture.Keys.builtIn
        #expect(HUDController.isBoosting(key, status: boosting))
        #expect(!HUDController.isBoosting(key, status: dimmed))
        #expect(!HUDController.isBoosting(key, status: try #require(ScriptedStatuses.status(named: "hud-off"))))
    }

    @Test func theBarFollowsTheLevelAndIsStandardWhileOff() {
        let settings = SettingsStore(defaults: InMemoryDefaults())
        let key = DisplayFixture.Keys.builtIn
        var preferences = DisplayPreferences()
        preferences.level = LevelPosition(-0.66)
        settings[DisplaySettings.perDisplay] = [key: preferences]
        let on = BoostStatus(isOn: true, isReady: true, pausedUntil: nil, autoOffAt: nil, displays: [], banner: nil,
                             symbol: .dimming)
        #expect(HUDController.level(of: key, status: on, settings: settings) == LevelPosition(-0.66))
        #expect(HUDController.level(of: key, status: .initial, settings: settings) == .standard)
        settings[DisplaySettings.linkLevels] = true
        settings[DisplaySettings.linkedLevel] = LevelPosition(0.75)
        #expect(HUDController.level(of: key, status: on, settings: settings) == LevelPosition(0.75))
    }
}
