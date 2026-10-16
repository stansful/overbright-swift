// OverbrightAppShellTests/HUDFitTests.swift — the HUD's text fits (DESIGN.md §6, §16: HUD text ≤ 200 pt; ARCHITECTURE.md
// §8.8 width rule `hud`): every value and reason of §12.9 in the HUD's type, in English and the pseudo-long locale
// (+40 %), plus whatever Design's `HUDText` makes for the gallery's HUD states once WP9's copy lands; the HUD itself is
// 280 × 56 pt whatever it says, and its bar draws the level. Measured in hosting views without a window.
import AppKit
import OverbrightCore
import OverbrightDesign
import OverbrightPanelUI
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
