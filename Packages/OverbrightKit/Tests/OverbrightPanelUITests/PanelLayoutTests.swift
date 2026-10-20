// OverbrightPanelUITests/PanelLayoutTests.swift — the panel's sections and layout: which displays get a card and
// which collapse into "Why?" (DESIGN.md §5.10; expanded from the start when nothing can boost, §5.11), the empty state,
// the one-time tip, the battery chip (§5.3, §5.9, §5.11), names told apart (§5.4), the 320-pt width, one card system
// (every card 304 pt, the slider row exactly the 280-pt inner width, §5.4), the scrolling list from four displays on
// (three whole cards and a peek, shrinking under the height cap, §5.1, §5.11), and the gallery of §5.13 complete. Views
// are measured in hosting views without a window: nothing is ordered in.
import AppKit
import OverbrightCore
import OverbrightDesign
import OverbrightPolicy
import OverbrightTestSupport
import SwiftUI
import Testing
@testable import OverbrightPanelUI

@MainActor @Suite struct PanelLayoutTests {
    /// Every name of DESIGN.md §5.13's states gallery.
    static let galleryNames = [
        "off", "standard", "boosting", "boosting-uncalibrated", "boosting-nits", "limited-by-macos", "safe-limit",
        "safe-limit-hdr-external", "safe-limit-oled", "small-gain", "below-full-brightness", "preparing",
        "no-extra-range", "still-no-extra-range", "dimmed", "extra-brightness-off", "linked", "banner-battery",
        "banner-low-power", "banner-heat", "banner-paused", "banner-focus", "banner-schedule", "heat-cap",
        "conflict-booster", "conflict-color-app", "conflict-may-interfere", "flicker-stop", "foreign-table",
        "full-screen-video", "full-screen", "paused-app", "oled-idle", "why-expanded",
        "nothing-capable", "two-identical-externals", "long-russian-name", "fill-light-card", "calibration-tip",
        "four-displays", "menubar-hidden", "move-to-applications", "hud-boost", "hud-dim", "hud-standard", "hud-off",
        "hud-preparing", "hud-blocked", "hud-two-displays", "hud-automation-timer", "hud-automation-battery",
        "hud-automation-low-power", "hud-automation-heat", "hud-automation-schedule", "hud-automation-back", "keep-level",
    ]

    @Test func theGalleryHasEveryStateOfTheDesign() throws {
        #expect(ScriptedStatuses.names == Self.galleryNames)
        for name in Self.galleryNames {
            let status = try #require(ScriptedStatuses.status(named: name), "\(name)")
            let services = try #require(ScriptedStatuses.services(named: name), "\(name)")
            #expect(status.isReady && !status.displays.isEmpty, "\(name)")
            #expect(services.boost.status == status, "\(name)")
            for display in status.displays {                     // the directory lists every display of the status
                #expect(services.displays.facts(for: display.key) != nil, "\(name): \(display.name)")
            }
        }
    }

    @Test func galleryStatesShowWhatTheirNamesSay() throws {
        func status(_ name: String) throws -> BoostStatus { try #require(ScriptedStatuses.status(named: name)) }
        #expect(try status("off").isOn == false)
        #expect(try status("preparing").symbol == .preparing)
        #expect(try status("dimmed").symbol == .dimming)
        #expect(try status("banner-paused").pausedUntil != nil)
        #expect(try status("flicker-stop").banner == .flickerStop(display: DisplayFixture.Keys.builtIn))
        #expect(try status("keep-level").pendingLowLevel != nil)
        #expect(try status("hud-automation-timer").lastChange?.kind == .timerEnded)
        #expect(try status("still-no-extra-range").displays.first?.failedTries == 2)
        let services = try #require(ScriptedStatuses.services(named: "linked"))
        #expect(services.settings[DisplaySettings.linkLevels])
        #expect(ScriptedStatuses.services(named: "fill-light-card")?.fillLight.isOn == true)
        #expect(ScriptedStatuses.expandsWhy(named: "why-expanded"))
    }

    @Test func galleryDecisionsCarryTheLevelOfTheirSettings() throws {
        // `DisplayDecision.level` is the level the reducer used; the readout names its preset (`Readout.values`).
        let boosting = try #require(ScriptedStatuses.status(named: "boosting")?.displays.first)
        #expect(boosting.decision?.level == LevelPreset.brightRoom.position)
        #expect(Readout.values(for: boosting, isMasterOn: true).preset == .brightRoom)
        let standard = try #require(ScriptedStatuses.status(named: "standard"))
        #expect(standard.displays.allSatisfy { $0.decision?.level == .standard })
        let linked = try #require(ScriptedStatuses.status(named: "linked"))
        #expect(linked.displays.allSatisfy { $0.decision?.level == DisplaySettings.linkedLevel.defaultValue })
    }

    // MARK: Sections

    @Test func capableDisplaysGetCardsAndTheRestCollapse() throws {
        let status = try #require(ScriptedStatuses.status(named: "nothing-capable"))
        let content = PanelContent(status: status, tipShown: true, calibrated: [], fillLightOn: false, hasBattery: true)
        #expect(content.cards.map(\.key) == [DisplayFixture.Keys.builtIn, DisplayFixture.Keys.mpg322ux])   // dim-only
        #expect(content.nonCapable.map(\.key) == [DisplayFixture.Keys.sidecar])
        #expect(content.showsNothingCapable)
        let boosting = try #require(ScriptedStatuses.status(named: "boosting"))
        let normal = PanelContent(status: boosting, tipShown: true, calibrated: [], fillLightOn: false, hasBattery: false)
        #expect(normal.cards.count == 2 && normal.nonCapable.isEmpty && !normal.showsNothingCapable)
        #expect(!normal.showsBatteryChip)
    }

    @Test func undecidedDisplaysGetCardsAndNoEmptyState() {
        let status = PreviewBoostControl(fixture: .sidecar).status       // no decisions yet
        let content = PanelContent(status: status, tipShown: true, calibrated: [], fillLightOn: false, hasBattery: true)
        #expect(content.cards.count == 2 && content.nonCapable.isEmpty && !content.showsNothingCapable)
    }

    @Test func theCalibrationTipShowsOnceAfterTheFirstBoostOfAnUncalibratedDisplay() throws {
        let status = try #require(ScriptedStatuses.status(named: "calibration-tip"))
        let key = DisplayFixture.Keys.builtIn
        #expect(PanelContent(status: status, tipShown: false, calibrated: [], fillLightOn: false, hasBattery: true)
            .calibrationTip == key)
        #expect(PanelContent(status: status, tipShown: true, calibrated: [], fillLightOn: false, hasBattery: true)
            .calibrationTip == nil)
        #expect(PanelContent(status: status, tipShown: false, calibrated: [key], fillLightOn: false, hasBattery: true)
            .calibrationTip == nil)
        let preparing = try #require(ScriptedStatuses.status(named: "preparing"))
        #expect(PanelContent(status: preparing, tipShown: false, calibrated: [], fillLightOn: false, hasBattery: true)
            .calibrationTip == nil)
    }

    @Test func identicalNamesAreNumberedInKeyOrder() throws {
        let status = try #require(ScriptedStatuses.status(named: "two-identical-externals"))
        let titles = CardTitles.titles(for: status.displays)
        let first = try #require(titles[DisplayFixture.Keys.mpg322ux])
        let second = try #require(titles[ScriptedParts.msiTwin.ref.key])
        #expect(first != second)
        #expect(first.hasSuffix("(1)") && second.hasSuffix("(2)"))
        #expect(titles[DisplayFixture.Keys.builtIn] == ScriptedParts.builtIn.name)
    }

    // MARK: Rendered layout

    @Test func thePanelIs320PointsWideInEveryState() throws {
        for name in ScriptedStatuses.names {
            let services = try #require(ScriptedStatuses.services(named: name))
            let view = PanelView(services: services, expandsWhy: ScriptedStatuses.expandsWhy(named: name))
                .overbrightThemeRoot()
            let size = NSHostingView(rootView: view).fittingSize
            #expect(size.width == PanelLayout.width, "\(name)")
            #expect(size.height > PanelLayout.barHeight * 2, "\(name)")
        }
    }

    private func height(_ view: some View) -> CGFloat {
        NSHostingView(rootView: view.overbrightThemeRoot()).fittingSize.height
    }

    private func cardHeights(_ services: OverbrightServices) -> [CGFloat] {
        services.boost.status.displays.map { display in
            height(DisplayCardView(status: display, isMasterOn: true, services: services))
        }
    }

    /// The panel without its cards: header, dividers, padding, footer (measured on the two-display panel).
    private func chrome() throws -> CGFloat {
        let two = try #require(ScriptedStatuses.services(named: "boosting"))
        return height(PanelView(services: two)) - cardHeights(two).reduce(0, +) - PanelLayout.cardGap
    }

    /// Four displays: the list shows three whole cards, its gaps and a 24-pt peek of the fourth, never a card cut
    /// through its slider (C-PANEL-13); the view settles on the measured cards.
    @Test func fourDisplaysScrollOnACardBoundaryWithAPeek() async throws {
        let four = try #require(ScriptedStatuses.services(named: "four-displays"))
        let fourCards = cardHeights(four)
        let chrome = try chrome()
        let expected = chrome + PanelLayout.scrollingListHeight(cardHeights: Array(fourCards.prefix(3)))
        let host = NSHostingView(rootView: PanelView(services: four).overbrightThemeRoot())
        #expect(await eventually {
            host.layoutSubtreeIfNeeded()
            return abs(host.fittingSize.height - expected) <= 2
        }, "four: \(host.fittingSize.height) pt, expected \(expected) pt, cards \(fourCards)")
        let three = fourCards.prefix(3).reduce(0, +) + 3 * PanelLayout.cardGap
        #expect(PanelLayout.scrollingListHeight(cardHeights: Array(fourCards.prefix(3))) == three + PanelLayout.scrollPeek)
        #expect(PanelLayout.scrollPeek < fourCards[3] / 2)                 // a peek, not most of the fourth card
        #expect(host.fittingSize.height < chrome + fourCards.reduce(0, +) + 3 * PanelLayout.cardGap)
    }

    /// When the 70 % height cap binds, the card list gives way and the header and the footer keep their place
    /// (C-PANEL-14).
    @Test func theCardListShrinksUnderTheHeightCap() throws {
        let four = try #require(ScriptedStatuses.services(named: "four-displays"))
        let cap = try chrome() + 150
        let controller = NSHostingController(rootView: PanelView(services: four).overbrightThemeRoot())
        let fitted = controller.sizeThatFits(in: CGSize(width: PanelLayout.width, height: cap))
        #expect(fitted.height <= cap + 1, "\(fitted.height) pt under a \(cap)-pt cap")
    }

    /// One card system (C-PANEL-2): display cards, the calibration tip, the Fill Light card and the "Why?" rows are all
    /// 304 pt wide, and the slider row is exactly the 280-pt inner width.
    @Test func everyCardIs304PointsWide() throws {
        for name in ["boosting", "extra-brightness-off", "nothing-capable", "four-displays", "long-russian-name"] {
            let services = try #require(ScriptedStatuses.services(named: name))
            for display in services.boost.status.displays where !PanelContent.isNonCapable(display) {
                let width = FitMeasure.idealWidth(DisplayCardView(status: display, isMasterOn: true, services: services))
                #expect(width == PanelLayout.cardWidth, "\(name): \(display.name) \(width) pt")
            }
        }
        let fill = try #require(ScriptedStatuses.services(named: "fill-light-card"))
        #expect(FitMeasure.idealWidth(FillLightCard(services: fill)) == PanelLayout.cardWidth)
        let tipServices = try #require(ScriptedStatuses.services(named: "calibration-tip"))
        let commands = PanelCommands(services: tipServices, source: .panel)
        let tip = TipHost(commands: commands)
        #expect(FitMeasure.idealWidth(tip) == PanelLayout.cardWidth)
        let why = try #require(ScriptedStatuses.services(named: "why-expanded"))
        let row = WhyHost(services: why)
        #expect(FitMeasure.width(row, offered: PanelLayout.cardWidth) == PanelLayout.cardWidth)
        #expect(2 * PanelLayout.sliderGlyph + 2 * Space.s + PanelLayout.trackWidth == PanelLayout.cardInnerWidth)
        #expect(PanelLayout.cardWidth == PanelLayout.width - 2 * PanelLayout.outerPadding)
    }

    /// Banners name the display a stop happened on, by its card title (DESIGN.md §12.3, C-PANEL-9).
    @Test func bannersNameTheDisplay() throws {
        let status = try #require(ScriptedStatuses.status(named: "flicker-stop"))
        let builtIn = DisplayFixture.Keys.builtIn
        let name = try #require(CardTitles.titles(for: status.displays)[builtIn])
        let booster = ConflictingApp(entryID: "b", severity: .booster, bundleID: nil, processID: 1, displayName: "B")
        for banner in [Banner.flickerStop(display: builtIn), .unattributedDrift(display: builtIn),
                       .attributedDrift(booster, display: builtIn)] {
            #expect(PanelView.bannerModel(banner, status: status).sentence.contains(name), "\(banner)")
        }
    }

    /// The "Why?" rows start expanded when no display can boost (DESIGN.md §5.11), collapsed otherwise (C-PANEL-12).
    @Test func theWhyRowsStartExpandedWhenNothingCanBoost() throws {
        let nothing = try #require(ScriptedStatuses.services(named: "nothing-capable"))
        let view = PanelView(services: nothing)
        #expect(view.content.showsNothingCapable)
        #expect(!view.focusOrder(view.content, status: nothing.boost.status).whyRows.isEmpty)
        let some = try #require(ScriptedStatuses.services(named: "why-expanded"))
        let collapsed = PanelView(services: some)
        #expect(!collapsed.content.showsNothingCapable)
        #expect(collapsed.focusOrder(collapsed.content, status: some.boost.status).whyRows.isEmpty)
    }

    @Test func theCardAndHelpBuildFromTheSeams() throws {
        let services = OverbrightServices.preview()
        let status = try #require(ScriptedStatuses.status(named: "off")?.displays.first)
        let card = NSHostingView(rootView: DisplayCardView(status: status, isMasterOn: false, services: services)
            .frame(width: PanelLayout.cardWidth).overbrightThemeRoot()).fittingSize
        #expect(card.width == PanelLayout.cardWidth && card.height > 40)
        let help = NSHostingView(rootView: HelpView(anchor: "no-extra-range").overbrightThemeRoot()).fittingSize
        #expect(help.width >= 480)
    }
}

/// The calibration tip with its own focus state (the panel's is private).
private struct TipHost: View {
    let commands: PanelCommands
    @FocusState private var focus: PanelFocus?

    var body: some View {
        CalibrationTipCard(display: DisplayFixture.Keys.builtIn, title: "Built-in Display", commands: commands,
                           focus: $focus)
    }
}

/// The expanded "Why?" row of a gallery state with its own state.
private struct WhyHost: View {
    let services: OverbrightServices
    @State private var isExpanded = true
    @FocusState private var focus: PanelFocus?

    var body: some View {
        let status = services.boost.status
        NonCapableRow(displays: status.displays.filter(PanelContent.isNonCapable),
                      titles: CardTitles.titles(for: status.displays), isExpanded: $isExpanded,
                      commands: PanelCommands(services: services, source: .panel), focus: $focus)
    }
}
