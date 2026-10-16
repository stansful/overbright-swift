// OverbrightPanelUITests/PanelLayoutTests.swift — the panel's sections and layout: which displays get a card and
// which collapse into "Why?" (DESIGN.md §5.10), the empty state, the one-time tip, the battery chip (§5.3, §5.9,
// §5.11), names told apart (§5.4), the 320-pt width and the scrolling list from four displays on (§5.1, §5.11), and the
// gallery of §5.13 complete. Views are measured in hosting views without a window: nothing is ordered in.
import AppKit
import OverbrightCore
import OverbrightDesign
import OverbrightPolicy
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
        "full-screen-video", "full-screen", "paused-app", "oled-idle", "compatibility", "why-expanded",
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

    @Test func fourDisplaysScrollWhileTwoDoNot() throws {
        func height(_ view: some View) -> CGFloat { NSHostingView(rootView: view.overbrightThemeRoot()).fittingSize.height }
        func cardHeights(_ services: OverbrightServices) -> [CGFloat] {
            services.boost.status.displays.map { display in
                height(DisplayCardView(status: display, isMasterOn: true, services: services).frame(width: PanelLayout.cardWidth))
            }
        }
        let two = try #require(ScriptedStatuses.services(named: "boosting"))
        let four = try #require(ScriptedStatuses.services(named: "four-displays"))
        let twoCards = cardHeights(two)
        let chrome = height(PanelView(services: two)) - twoCards.reduce(0, +) - PanelLayout.cardGap
        let fourCards = cardHeights(four)
        let unscrolled = chrome + fourCards.reduce(0, +) + 3 * PanelLayout.cardGap
        let fourHeight = height(PanelView(services: four))
        // The list of four is the fixed scrolling height, shorter than four stacked cards.
        #expect(abs(fourHeight - (chrome + PanelLayout.scrollingListHeight)) <= 2,
                "four: \(fourHeight) pt, chrome \(chrome) pt, cards \(fourCards)")
        #expect(fourHeight < unscrolled)
        // The fixed height shows three cards, never all four (DESIGN.md §5.11).
        let three = fourCards.prefix(3).reduce(0, +) + 2 * PanelLayout.cardGap
        #expect(three <= PanelLayout.scrollingListHeight && PanelLayout.scrollingListHeight < unscrolled - chrome,
                "cards \(fourCards)")
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
