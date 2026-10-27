// OverbrightPanelUITests/PanelKeyboardTests.swift — a keyboard-only walk of the panel (DESIGN.md §5.12, §15): the Tab
// order with every element present, ⇧Tab back, wrapping, ↑ / ↓ between the cards' sliders, and the order the panel
// derives from what it shows (chips and Turn on only where a card has them, the banner's button, the battery chip only
// with a battery, the Fill Light card). Hosted in a window that is never ordered in, every kind of element runs on its
// keys: Space toggles the master switch and opens a chip's popover or a footer chip's menu, Return runs a button and
// opens the "⋯" menu, ← and → move the Fill Light sliders (C-PANEL-7); keyboard menus are recorded, not tracked. The
// panel's ⌘ keys are the shell's (`PanelControllerTests`).
import AppKit
import Foundation
import OverbrightCore
import OverbrightDesign
import OverbrightTestSupport
import SwiftUI
import Testing
@testable import OverbrightPanelUI

@MainActor @Suite struct PanelKeyboardTests {
    private let a = DisplayFixture.Keys.builtIn
    private let b = DisplayFixture.Keys.mpg322ux

    /// Every element present: "Show external displays…", two cards (the second with a chip and Turn on), "Why?" expanded
    /// with a fix, the banner's two buttons, the tip, all three footer chips, the Fill Light card.
    private var everything: PanelFocusOrder {
        PanelFocusOrder(hasExternalsHidden: true,
                        cards: [.init(key: a, hasChip: true, hasTurnOn: false), .init(key: b, hasChip: true, hasTurnOn: true)],
                        hasWhy: true, whyRows: [.init(key: DisplayFixture.Keys.sidecar, hasFix: true)], bannerButtons: 2,
                        hasTip: true, hasBatteryChip: true, hasFillLightCard: true)
    }

    @Test func tabWalksTheDesignOrderWithEveryElementPresent() {
        let sidecar = DisplayFixture.Keys.sidecar
        let expected: [PanelFocus] = [
            .masterSwitch, .showExternals, .slider(a), .chip(a), .slider(b), .chip(b), .turnOn(b), .why, .fix(sidecar), .learnMore(sidecar),
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

// MARK: Keys on every element, hosted (C-PANEL-7)

/// What a hosted element did when its key arrived.
@MainActor final class KeyRecorder {
    /// The element that has focus.
    var focused: PanelFocus?
    /// The rows of every keyboard menu opened, in order.
    var menus: [[String]] = []
    /// A flag the host's own state mirrors (a chip's popover, the "Why?" row).
    var flag = false
}

/// Hosts `content` with a panel focus state that moves to `value` once shown, records keyboard menus instead of
/// tracking them, and mirrors focus into `recorder`.
private struct FocusHost<Content: View>: View {
    let value: PanelFocus
    let recorder: KeyRecorder
    @ViewBuilder let content: (FocusState<PanelFocus?>.Binding) -> Content
    @FocusState private var focus: PanelFocus?

    var body: some View {
        content($focus)
            .environment(\.panelMenuPresenter, PanelMenuPresenter { [recorder] _, items in
                recorder.menus.append(items.map { $0.isSeparatorItem ? "---" : $0.title })
            })
            .onChange(of: focus) { recorder.focused = focus }
            .onAppear { focus = value }
            .overbrightThemeRoot()
    }
}

/// A borderless window that is never ordered in, with `view` as its content, and key presses sent to it.
@MainActor private struct KeyWindow {
    let window: NSWindow

    init(_ view: some View) {
        let host = NSHostingView(rootView: view)
        host.frame = CGRect(origin: .zero, size: CGSize(width: PanelLayout.width, height: max(host.fittingSize.height, 60)))
        window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: true)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        window.makeFirstResponder(host)
    }

    func press(_ key: Key) {
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                     windowNumber: window.windowNumber, context: nil, characters: key.characters,
                                     charactersIgnoringModifiers: key.characters, isARepeat: false, keyCode: key.code)
        if let event { window.sendEvent(event) }
    }

    enum Key {
        case space, `return`, left, right
        var characters: String {
            switch self {
            case .space: " "
            case .return: "\r"
            case .left: String(Character(UnicodeScalar(NSLeftArrowFunctionKey) ?? " "))
            case .right: String(Character(UnicodeScalar(NSRightArrowFunctionKey) ?? " "))
            }
        }
        var code: UInt16 {
            switch self {
            case .space: 49
            case .return: 36
            case .left: 123
            case .right: 124
            }
        }
    }
}

@MainActor @Suite struct PanelKeyActivationTests {
    private let builtIn = DisplayFixture.Keys.builtIn
    private let msi = DisplayFixture.Keys.mpg322ux

    /// Hosts `content` focused on `value`, waits for the focus, then presses `key`.
    private func press(_ key: KeyWindow.Key, on value: PanelFocus, recorder: KeyRecorder,
                       @ViewBuilder _ content: @escaping (FocusState<PanelFocus?>.Binding) -> some View) async -> KeyWindow {
        let window = KeyWindow(FocusHost(value: value, recorder: recorder, content: content))
        _ = await eventually { recorder.focused == value }
        window.press(key)
        return window
    }

    @Test func spaceTogglesTheMasterSwitchAndReturnOpensTheOverflowMenu() async throws {
        let services = try #require(ScriptedStatuses.services(named: "boosting"))
        let boost = try #require(services.boost as? PreviewBoostControl)
        let commands = PanelCommands(services: services, source: .panel)
        let recorder = KeyRecorder()
        let header = { (focus: FocusState<PanelFocus?>.Binding) in
            PanelHeader(status: services.boost.status, fillLightOn: false, symbol: { _ in Image(symbol: .sunMax) },
                        commands: commands, focus: focus)
        }
        _ = await press(.space, on: .masterSwitch, recorder: recorder, header)
        #expect(await eventually { boost.calls.contains("setOn(false,panel)") })
        let overflow = KeyRecorder()
        _ = await press(.return, on: .overflow, recorder: overflow, header)
        #expect(await eventually { overflow.menus.count == 1 })
        #expect(overflow.menus.first == OverflowItem.items(isDimmed: false, fillLightOn: false)
            .map { $0 == .separator ? "---" : $0.title })
    }

    @Test(arguments: [PanelFocus.footerBattery, .footerAutoPause, .footerTimer])
    func spaceOpensAFooterChipsMenu(_ value: PanelFocus) async throws {
        let settings = SettingsStore(defaults: InMemoryDefaults())
        let chips = FooterChips.chips(settings: settings, hasBattery: true, autoOffAt: nil,
                                      now: Date(timeIntervalSinceReferenceDate: 800_000_000), editApps: {})
        let recorder = KeyRecorder()
        _ = await press(.space, on: value, recorder: recorder) { focus in PanelFooter(chips: chips, focus: focus) }
        #expect(await eventually { recorder.menus.count == 1 }, "\(value)")
        let chip = try #require(chips.first { PanelFooter.focus(for: $0.kind) == value })
        #expect(recorder.menus.first == KeyboardMenu.items(chip.menu).map { $0.isSeparatorItem ? "---" : $0.title })
    }

    @Test func theFillLightCardTakesSpaceReturnAndArrows() async throws {
        let services = try #require(ScriptedStatuses.services(named: "fill-light-card"))
        let settings = services.settings
        let card = { (focus: FocusState<PanelFocus?>.Binding) in FillLightCard(services: services, focus: focus) }
        let display = KeyRecorder()
        _ = await press(.space, on: .fillLightDisplay, recorder: display, card)
        #expect(await eventually { display.menus.count == 1 })
        #expect(display.menus.first == services.displays.displays.map(\.name))
        let brightness = settings[FillLightSettings.brightness]
        _ = await press(.right, on: .fillLightBrightness, recorder: KeyRecorder(), card)
        #expect(await eventually { abs(settings[FillLightSettings.brightness] - min(brightness + 0.05, 1)) < 0.001 })
        let warmth = settings[FillLightSettings.warmth]
        _ = await press(.left, on: .fillLightWarmth, recorder: KeyRecorder(), card)
        #expect(await eventually { settings[FillLightSettings.warmth] < warmth })
        _ = await press(.return, on: .fillLightTurnOff, recorder: KeyRecorder(), card)
        #expect(await eventually { !services.fillLight.isOn })
    }

    @Test func spaceOpensTheChipsPopoverAndReturnRunsTurnOn() async throws {
        let services = try #require(ScriptedStatuses.services(named: "extra-brightness-off"))
        let status = try #require(services.boost.status.displays.first { $0.key == msi })
        let chip = try #require(ChipModel.make(reason: .boostNotEnabled, phase: .idle, failedTries: 0))
        let recorder = KeyRecorder()
        _ = await press(.space, on: .chip(msi), recorder: recorder) { focus in ChipHost(chip: chip, recorder: recorder,
                                                                                         focus: focus, key: status.key) }
        #expect(await eventually { recorder.flag })                        // the popover's state, as the card binds it
        let asked = KeyRecorder()
        let commands = PanelCommands(services: services, source: .panel,
                                     confirmOLED: { _ in asked.flag = true; return false }, openURL: { _ in })
        _ = await press(.return, on: .turnOn(msi), recorder: KeyRecorder()) { focus in
            DisplayCardView(status: status, isMasterOn: true, services: services, title: nil, focus: focus,
                            commands: commands)
        }
        #expect(await eventually { asked.flag })                           // Turn on asks the OLED question
    }

    @Test func theTipAndTheWhyRowTakeReturn() async throws {
        let services = try #require(ScriptedStatuses.services(named: "calibration-tip"))
        services.settings[OnboardingSettings.calibrationTipShown] = false
        let commands = PanelCommands(services: services, source: .panel)
        _ = await press(.return, on: .tipNotNow, recorder: KeyRecorder()) { focus in
            CalibrationTipCard(display: DisplayFixture.Keys.builtIn, title: "Built-in", commands: commands, focus: focus)
        }
        #expect(await eventually { services.settings[OnboardingSettings.calibrationTipShown] })
        let why = try #require(ScriptedStatuses.services(named: "why-expanded"))
        let recorder = KeyRecorder()
        _ = await press(.return, on: .why, recorder: recorder) { focus in WhyKeyHost(services: why, recorder: recorder,
                                                                                    focus: focus) }
        #expect(await eventually { recorder.flag })                        // expanded
    }

    /// The key rule of every element: Space and Return run it once (a held key does not repeat it), ← and → step a
    /// slider toward the end they point at (mirrored right to left), and every other key, or a key with a modifier,
    /// travels on to the panel.
    @Test func theKeyRuleOfAnElement() {
        var runs = 0
        var steps: [Bool] = []
        let activate = PanelFocusable.Keys.activate { runs += 1 }
        let step = PanelFocusable.Keys.step { steps.append($0) }
        func handle(_ key: KeyEquivalent, _ keys: PanelFocusable.Keys, modifiers: EventModifiers = [],
                    repeat isRepeat: Bool = false, direction: LayoutDirection = .leftToRight) -> KeyPress.Result {
            PanelFocusable.handle(key, modifiers: modifiers, isRepeat: isRepeat, keys: keys, direction: direction)
        }
        #expect(handle(.space, activate) == .handled && handle(.return, activate) == .handled && runs == 2)
        #expect(handle(.space, activate, repeat: true) == .ignored && runs == 2)
        #expect(handle(.return, activate, modifiers: .control) == .ignored)      // ⌃↩ is the card's context menu
        #expect(handle(.tab, activate) == .ignored && handle(.leftArrow, activate) == .ignored)
        #expect(handle(.rightArrow, step) == .handled && handle(.leftArrow, step, repeat: true) == .handled)
        #expect(handle(.rightArrow, step, direction: .rightToLeft) == .handled)
        #expect(steps == [true, false, false])
        #expect(handle(.space, step) == .ignored && handle(.upArrow, step) == .ignored)   // ↑ / ↓ move between cards
    }
}

/// A chip wrapped as the card wraps it: its popover state bound (here to the recorder), opened by the focused
/// wrapper's Space.
private struct ChipHost: View {
    let chip: ChipModel
    let recorder: KeyRecorder
    let focus: FocusState<PanelFocus?>.Binding
    let key: DisplayKey

    var body: some View {
        let shown = Binding(get: { recorder.flag }, set: { recorder.flag = $0 })
        StatusChip(chip, actions: [], isPresented: shown)
            .panelFocus(focus, .chip(key)) { shown.wrappedValue = true }
    }
}

/// The "Why?" row with its expansion bound to the recorder.
private struct WhyKeyHost: View {
    let services: OverbrightServices
    let recorder: KeyRecorder
    let focus: FocusState<PanelFocus?>.Binding

    var body: some View {
        let status = services.boost.status
        NonCapableRow(displays: status.displays.filter(PanelContent.isNonCapable),
                      titles: CardTitles.titles(for: status.displays),
                      isExpanded: Binding(get: { recorder.flag }, set: { recorder.flag = $0 }),
                      commands: PanelCommands(services: services, source: .panel), focus: focus)
    }
}
