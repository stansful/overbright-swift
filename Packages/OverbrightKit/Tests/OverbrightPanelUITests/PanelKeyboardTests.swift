// OverbrightPanelUITests/PanelKeyboardTests.swift — a keyboard-only walk of the panel (DESIGN.md §5.12, §15): the Tab
// order with every element present, ⇧Tab back, wrapping, ↑ / ↓ between the cards' sliders, and the order the panel
// derives from what it shows (chips and Turn on only where a card has them, the banner's button, the battery chip only
// with a battery, the Fill Light card). The panel's ⌘ keys are the shell's (`PanelControllerTests`).
import OverbrightCore
import Testing
@testable import OverbrightPanelUI

@MainActor @Suite struct PanelKeyboardTests {
    private let a = DisplayFixture.Keys.builtIn
    private let b = DisplayFixture.Keys.mpg322ux

    /// Every element present: two cards (the second with a chip and Turn on), "Why?" expanded with a fix, the banner's
    /// two buttons, the tip, all three footer chips, the Fill Light card.
    private var everything: PanelFocusOrder {
        PanelFocusOrder(cards: [.init(key: a, hasChip: true, hasTurnOn: false), .init(key: b, hasChip: true, hasTurnOn: true)],
                        hasWhy: true, whyRows: [.init(key: DisplayFixture.Keys.sidecar, hasFix: true)], bannerButtons: 2,
                        hasTip: true, hasBatteryChip: true, hasFillLightCard: true)
    }

    @Test func tabWalksTheDesignOrderWithEveryElementPresent() {
        let sidecar = DisplayFixture.Keys.sidecar
        let expected: [PanelFocus] = [
            .masterSwitch, .slider(a), .chip(a), .slider(b), .chip(b), .turnOn(b), .why, .fix(sidecar), .learnMore(sidecar),
            .bannerPrimary, .bannerSecondary, .tipCalibrate, .tipNotNow, .footerBattery, .footerAutoPause, .footerTimer,
            .fillLightDisplay, .fillLightBrightness, .fillLightWarmth, .fillLightTurnOff, .overflow,
        ]
        #expect(everything.order == expected)
        // Pressing Tab from nothing visits every element once, in order, and wraps to the master switch.
        var focus: PanelFocus?
        var visited: [PanelFocus] = []
        for _ in expected.indices {
            focus = everything.next(after: focus)
            if let focus { visited.append(focus) }
        }
        #expect(visited == expected)
        #expect(everything.next(after: focus) == .masterSwitch)
    }

    @Test func shiftTabWalksBackAndWraps() {
        let order = everything.order
        var focus: PanelFocus? = .masterSwitch
        var visited: [PanelFocus] = []
        for _ in order.indices {
            focus = everything.previous(before: focus)
            if let focus { visited.append(focus) }
        }
        #expect(visited == Array(order.reversed().dropLast()) + [.masterSwitch])
        #expect(everything.previous(before: nil) == .overflow)
    }

    @Test func upAndDownMoveBetweenSlidersOnly() {
        #expect(everything.slider(from: .slider(a), down: true) == .slider(b))
        #expect(everything.slider(from: .slider(b), down: false) == .slider(a))
        #expect(everything.slider(from: .slider(b), down: true) == nil)          // the last card: no wrap
        #expect(everything.slider(from: .slider(a), down: false) == nil)
        #expect(everything.slider(from: .chip(a), down: true) == nil)            // ↑ / ↓ belong to sliders
        #expect(everything.slider(from: nil, down: true) == nil)
    }

    @Test func focusOnSomethingNoLongerShownRestartsTheWalk() {
        let small = PanelFocusOrder(cards: [.init(key: a, hasChip: false, hasTurnOn: false)], hasWhy: false, whyRows: [],
                                    bannerButtons: 0, hasTip: false, hasBatteryChip: false, hasFillLightCard: false)
        #expect(small.order == [.masterSwitch, .slider(a), .footerAutoPause, .footerTimer, .overflow])
        #expect(small.next(after: .chip(b)) == .masterSwitch)
        #expect(small.previous(before: .fillLightWarmth) == .overflow)
    }

    @Test func thePanelDerivesItsOrderFromWhatItShows() throws {
        let services = try #require(ScriptedStatuses.services(named: "extra-brightness-off"))
        let view = PanelView(services: services)
        let status = services.boost.status
        let content = view.content
        let order = view.focusOrder(content, status: status)
        // The MSI's extra brightness is off at a boost level: its Turn on is reachable (whatever Design's chip says).
        let msiCard = try #require(order.cards.first { $0.key == b })
        #expect(msiCard.hasTurnOn)
        #expect(order.order.contains(.turnOn(b)))
        let builtInCard = try #require(order.cards.first { $0.key == a })
        #expect(!builtInCard.hasTurnOn && !order.order.contains(.turnOn(a)))
        #expect(order.hasBatteryChip == content.showsBatteryChip)
        #expect(order.order.first == .masterSwitch && order.order.last == .overflow)
        #expect(order.order.contains(.slider(a)) && order.order.contains(.slider(b)))
        let banner = try #require(ScriptedStatuses.services(named: "banner-low-power"))
        let bannerView = PanelView(services: banner)
        #expect(bannerView.focusOrder(bannerView.content, status: banner.boost.status).bannerButtons == 1)
        let heat = try #require(ScriptedStatuses.services(named: "banner-heat"))
        let heatView = PanelView(services: heat)
        #expect(heatView.focusOrder(heatView.content, status: heat.boost.status).bannerButtons == 0)   // no action
    }
}
