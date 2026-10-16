// OverbrightPanelUI/Panel/PanelFocus.swift — the panel's keyboard map as data: every focusable element and the Tab
// order of DESIGN.md §5.12 (master switch → per card: slider, chip, Turn on → "Why?" and, when expanded, each row's fix
// and Learn more → banner buttons → the calibration tip's buttons → footer chips → the Fill Light card → "⋯"), plus
// ↑ / ↓ between the cards' sliders. The view binds `@FocusState` to it; `PanelKeyboardTests` walk it.
import OverbrightCore

/// A focusable element of the panel.
public nonisolated enum PanelFocus: Hashable, Sendable {
    /// The header's master switch.
    case masterSwitch
    /// A card's level slider.
    case slider(DisplayKey)
    /// A card's status chip.
    case chip(DisplayKey)
    /// A card's inline "Turn on" (extra brightness off for the display).
    case turnOn(DisplayKey)
    /// The "Why?" button of the collapsed row.
    case why
    /// An expanded row's fix button.
    case fix(DisplayKey)
    /// An expanded row's "Learn more" link.
    case learnMore(DisplayKey)
    /// The banner's primary button.
    case bannerPrimary
    /// The banner's secondary button.
    case bannerSecondary
    /// The calibration tip's "Calibrate…".
    case tipCalibrate
    /// The calibration tip's "Not now".
    case tipNotNow
    /// The Battery footer chip.
    case footerBattery
    /// The Auto-pause footer chip.
    case footerAutoPause
    /// The Timer footer chip.
    case footerTimer
    /// The Fill Light card's display pop-up.
    case fillLightDisplay
    /// The Fill Light card's brightness slider.
    case fillLightBrightness
    /// The Fill Light card's warmth slider.
    case fillLightWarmth
    /// The Fill Light card's "Turn off".
    case fillLightTurnOff
    /// The header's "⋯" menu.
    case overflow
}

/// What the panel shows, as far as focus is concerned.
public struct PanelFocusOrder: Hashable {
    /// One card's focusable parts.
    public struct Card: Hashable {
        /// The display.
        public var key: DisplayKey
        /// The card shows a chip.
        public var hasChip: Bool
        /// The card shows the inline Turn on button.
        public var hasTurnOn: Bool
        /// A card.
        public init(key: DisplayKey, hasChip: Bool, hasTurnOn: Bool) {
            self.key = key; self.hasChip = hasChip; self.hasTurnOn = hasTurnOn
        }
    }

    /// One expanded "Why?" row's buttons.
    public struct WhyRow: Hashable {
        /// The display.
        public var key: DisplayKey
        /// The row has a fix button.
        public var hasFix: Bool
        /// A row.
        public init(key: DisplayKey, hasFix: Bool) { self.key = key; self.hasFix = hasFix }
    }

    /// The cards, in order.
    public var cards: [Card]
    /// The "Why?" line shows.
    public var hasWhy: Bool
    /// The expanded rows (empty while collapsed).
    public var whyRows: [WhyRow]
    /// The banner's buttons: 0, 1 or 2.
    public var bannerButtons: Int
    /// The calibration tip shows.
    public var hasTip: Bool
    /// The Battery footer chip shows.
    public var hasBatteryChip: Bool
    /// The Fill Light card shows.
    public var hasFillLightCard: Bool

    /// The order of the panel's elements.
    public init(cards: [Card], hasWhy: Bool, whyRows: [WhyRow], bannerButtons: Int, hasTip: Bool, hasBatteryChip: Bool,
                hasFillLightCard: Bool) {
        self.cards = cards; self.hasWhy = hasWhy; self.whyRows = whyRows; self.bannerButtons = bannerButtons
        self.hasTip = hasTip; self.hasBatteryChip = hasBatteryChip; self.hasFillLightCard = hasFillLightCard
    }

    /// Every element in Tab order.
    public var order: [PanelFocus] {
        var order: [PanelFocus] = [.masterSwitch]
        for card in cards {
            order.append(.slider(card.key))
            if card.hasChip { order.append(.chip(card.key)) }
            if card.hasTurnOn { order.append(.turnOn(card.key)) }
        }
        if hasWhy {
            order.append(.why)
            for row in whyRows {
                if row.hasFix { order.append(.fix(row.key)) }
                order.append(.learnMore(row.key))
            }
        }
        if bannerButtons > 0 { order.append(.bannerPrimary) }
        if bannerButtons > 1 { order.append(.bannerSecondary) }
        if hasTip { order += [.tipCalibrate, .tipNotNow] }
        if hasBatteryChip { order.append(.footerBattery) }
        order += [.footerAutoPause, .footerTimer]
        if hasFillLightCard { order += [.fillLightDisplay, .fillLightBrightness, .fillLightWarmth, .fillLightTurnOff] }
        order.append(.overflow)
        return order
    }

    /// The element after `focus` (Tab), wrapping at the end; the first element when nothing (or something no longer
    /// shown) has focus.
    public func next(after focus: PanelFocus?) -> PanelFocus { step(from: focus, by: 1) }

    /// The element before `focus` (⇧Tab), wrapping at the start; the last element when nothing has focus.
    public func previous(before focus: PanelFocus?) -> PanelFocus { step(from: focus, by: -1) }

    /// ↑ / ↓: the previous or next card's slider from a slider; nil anywhere else, and at the first or last card.
    public func slider(from focus: PanelFocus?, down: Bool) -> PanelFocus? {
        guard case .slider(let key)? = focus, let index = cards.firstIndex(where: { $0.key == key }) else { return nil }
        let target = index + (down ? 1 : -1)
        guard cards.indices.contains(target) else { return nil }
        return .slider(cards[target].key)
    }

    private func step(from focus: PanelFocus?, by delta: Int) -> PanelFocus {
        let order = order
        guard let focus, let index = order.firstIndex(of: focus) else {
            return delta > 0 ? order[0] : order[order.count - 1]
        }
        return order[(index + delta + order.count) % order.count]
    }
}
