// OverbrightAppShellTests/HUDFitTests.swift — the HUD's text fits (DESIGN.md §6, §16: HUD text ≤ 200 pt; ARCHITECTURE.md
// §8.8 width rule `hud`): every value and reason of §12.9 in the HUD's type, in English and the pseudo-long locale
// (+40 %), plus whatever Design's `HUDText` makes for the gallery's HUD states; in every language Overbright ships
// (WP15) the values, the reasons and the Keep-this-level prompt are measured too; the HUD itself is
// 280 × 56 pt whatever it says, its lines are laid out as §6 says (the frames the view reports, in a window that is
// never ordered in), and its bar draws the level. Text is measured in hosting views without a window.
import AppKit
import OverbrightCore
import OverbrightDesign
import OverbrightPanelUI
import OverbrightPolicy
import OverbrightTestSupport
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
    static let valueFont = OverbrightFont.hudValue.font
    static let labelFont = OverbrightFont.hudLabel.font

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
        let lines = reasons.compactMap { reason in
            HUDText.make(LevelChange(sequence: 1, kind: .blocked(reason), source: .shortcut, display: nil), status: status,
                         on: nil, in: language)?.reason
        }
        return (values + gallery.compactMap(\.value), lines + changes + gallery.compactMap(\.reason))
    }

    @Test(arguments: languages)
    func valuesAndReasonsFitInEveryLanguage(_ code: String) throws {
        // Design's table of the language, required: falling back to English would measure English (C-PANEL-33).
        let language = try #require(CopyLanguage.named(code), "\(code): no Design table")
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
    /// between the prompt's insets, in the StatusMenu words `LevelConfirmationPromptView` reads.
    @Test(arguments: languages)
    func theKeepLevelPromptFitsInEveryLanguage(_ code: String) throws {
        // The language's own table, required: falling back to `.module` would measure English (C-PANEL-33).
        let folder = Bundle.module.resourceURL?.appendingPathComponent("\(code).lproj", isDirectory: true)
        let bundle = try #require(folder.flatMap { FileManager.default.fileExists(atPath: $0.path) ? Bundle(url: $0) : nil },
                                  "\(code): no \(code).lproj in the shell's resources")
        let locale = Locale(identifier: code)
        let title = String(localized: "Keep this level?", table: "StatusMenu", bundle: bundle, locale: locale)
        let countdown = String(localized: "Going back in \(10) s", table: "StatusMenu", bundle: bundle, locale: locale)
        let goBack = String(localized: "Go Back", table: "StatusMenu", bundle: bundle, locale: locale)
        let keep = String(localized: "Keep", table: "StatusMenu", bundle: bundle, locale: locale)
        let room = HUDPlacement.promptSize.width - 2 * Space.l
        #expect(width(title, .headline) <= room, "\(code): «\(title)» \(width(title, .headline)) pt")
        let measured = width(countdown, .callout.monospacedDigit())
        #expect(measured <= room, "\(code): «\(countdown)» \(measured) pt")
        let row = NSHostingView(rootView: HStack(spacing: Space.m) {
            Button(action: {}) { Text(verbatim: goBack) }
            Button(action: {}) { Text(verbatim: keep) }
        }.fixedSize()).fittingSize.width
        #expect(row <= room, "\(code): «\(goBack)» «\(keep)» \(row) pt")
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

    /// The frames of the HUD's lines for `text`, as the view lays them out in its 280 × 56 pt.
    private func layout(of text: HUDText) async -> [HUDView.LayoutPart: CGRect] {
        final class Frames { var parts: [HUDView.LayoutPart: CGRect] = [:] }
        let frames = Frames()
        let view = HUDView(text: text, level: LevelPosition(0.75), isBoosting: true,
                           layoutReport: { frames.parts[$0] = $1 })
        let host = NSHostingView(rootView: view.overbrightThemeRoot())
        host.frame = CGRect(origin: .zero, size: HUDPlacement.size)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: true)
        window.contentView = host
        defer { window.contentView = nil }
        let expected = text.displayName == nil ? 2 : 3
        _ = await eventually {
            host.layoutSubtreeIfNeeded()
            return frames.parts.count == expected
        }
        return frames.parts
    }

    @Test func theValueKeepsItsWidthBesideTheBar() async throws {
        // The longest English value next to a display name still shows whole (the bar has its own line).
        let value = "Sunlight · ≈ ×2.04"
        let text = HUDText(symbol: .sunMaxFill, displayName: "Built-in Retina Display", value: value, reason: nil,
                           announcement: "")
        let full = width(value, Self.valueFont)
        #expect(full <= HUDView.textWidth)
        let lines = await layout(of: text)
        let drawn = try #require(lines[.value])
        let bar = try #require(lines[.bar])
        #expect(abs(drawn.width - full) <= 0.5, "the value is cut: \(drawn.width) of \(full) pt")
        #expect(drawn.maxY <= bar.minY, "the bar is not under the value")
    }

    @Test func theBoostFillIsWarmOnlyWithExtraLight() throws {
        let boosting = try #require(ScriptedStatuses.status(named: "hud-boost"))
        let dimmed = try #require(ScriptedStatuses.status(named: "hud-dim"))
        let key = DisplayFixture.Keys.builtIn
        #expect(HUDController.isBoosting(key, status: boosting))
        #expect(!HUDController.isBoosting(key, status: dimmed))
        #expect(!HUDController.isBoosting(key, status: try #require(ScriptedStatuses.status(named: "hud-off"))))
    }

    /// The bar draws the level the display is set to — the panel's thumb — and Standard while off (C-PANEL-1).
    @Test func theBarFollowsTheLevelAndIsStandardWhileOff() throws {
        let services = try #require(ScriptedStatuses.services(named: "boosting"))
        let key = DisplayFixture.Keys.builtIn
        var all = services.settings[DisplaySettings.perDisplay]
        var preferences = all[key] ?? DisplayPreferences()
        preferences.level = LevelPosition(-0.66)
        all[key] = preferences
        services.settings[DisplaySettings.perDisplay] = all
        let on = services.boost.status
        #expect(HUDContent.level(of: key, status: on, services: services) == LevelPosition(-0.66))
        var off = on
        off.isOn = false
        #expect(HUDContent.level(of: key, status: off, services: services) == .standard)
        services.settings[DisplaySettings.linkLevels] = true
        services.settings[DisplaySettings.linkedLevel] = LevelPosition(0.75)
        #expect(HUDContent.level(of: key, status: on, services: services) == LevelPosition(0.75))
    }

    /// A display whose extra brightness is off, or whose boost half is unavailable, draws Standard however high its
    /// stored level is, as the panel's thumb and readout do (C-PANEL-1).
    @Test func theBarOfASwitchedOffDisplayIsStandard() throws {
        let services = try #require(ScriptedStatuses.services(named: "extra-brightness-off"))
        let msi = DisplayFixture.Keys.mpg322ux
        let status = services.boost.status
        #expect(services.settings[DisplaySettings.perDisplay][msi]?.level.isBoost == true)
        #expect(HUDContent.level(of: msi, status: status, services: services) == .standard)
        let change = LevelChange(sequence: 1, kind: .level, source: .shortcut, display: msi)
        let text = try #require(HUDContent.text(for: change, status: status, on: msi, services: services))
        #expect(text.value == ValueText.make(ReadoutValues(state: .standard, appliedGain: 1, requestedGain: nil, nits: nil,
                                                           preset: nil, isEstimate: true, dimPercent: nil)).text)
    }

    /// With two displays the name has its own line above the value and the bar, drawn whole (not "Built…splay") and
    /// at the value's leading edge, and all three lines stay inside the HUD (C-PANEL-11); with one display there is no
    /// name line.
    @Test func theNameHasItsOwnLineAboveTheValue() async throws {
        let name = "Built-in Liquid Retina XDR Display"
        let full = width(name, Self.labelFont)
        #expect(full <= HUDView.textWidth)
        let text = HUDText(symbol: .sunMaxFill, displayName: name, value: "Sunlight · ≈ ×2.04", reason: nil,
                           announcement: "")
        let lines = await layout(of: text)
        let nameLine = try #require(lines[.name])
        let value = try #require(lines[.value])
        let bar = try #require(lines[.bar])
        #expect(abs(nameLine.width - full) <= 0.5, "the name is cut: \(nameLine.width) of \(full) pt")
        #expect(nameLine.maxY <= value.minY, "the name is not above the value: \(nameLine) \(value)")
        #expect(abs(nameLine.minX - value.minX) <= 0.5, "the name and the value start at \(nameLine.minX), \(value.minX)")
        #expect(value.maxY <= bar.minY, "the bar is not under the value")
        let hud = CGRect(origin: .zero, size: HUDPlacement.size)
        for line in [nameLine, value, bar] {
            #expect(hud.contains(line), "a line leaves the HUD: \(line)")
        }
        let alone = HUDText(symbol: .sunMaxFill, displayName: nil, value: "Sunlight · ≈ ×2.04", reason: nil,
                            announcement: "")
        let single = await layout(of: alone)
        #expect(single[.name] == nil && single[.value] != nil && single[.bar] != nil, "\(single)")
    }
}
