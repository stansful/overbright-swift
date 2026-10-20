// OverbrightPanelUI/Panel/PanelView.swift — the panel's content: header, Fill Light card, banner, calibration tip, the
// empty-state sentence, one card per display that can boost or dim, the "Why?" row, footer chips. DESIGN.md §5.1–§5.12
// (the card list scrolls beyond the height cap or from four displays on: three whole cards and a 24-pt peek of the
// next one, shrinking when the cap binds; header, banner and footer stay), §5.11 (the "Why?" rows start expanded when
// no display can boost), §12.3 (banners name the display), §2.0 rule 3 (the shell's hosting view applies
// `.overbrightThemeRoot` once). The master switch draws its "on" state in the accent colour although the panel is not
// key when clicked open (§5.1, `PanelSwitchStyle`). The window, its glass and its placement are the shell's
// (`PanelController`). Redraw on change only (§17): each pass reads the settings once and builds each card's model
// once; cards, header and footer are `Equatable` on what they draw, so a status change redraws only what it changed,
// and the card list scrolls in a `ScrollView` whose ideal height is the list's (a `ViewThatFits` built a measuring copy
// of every card on every redraw).
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// The panel.
public struct PanelView: View {
    private let services: OverbrightServices
    private let symbol: (StatusSymbolState) -> Image
    private let takesFocus: Bool
    private let commands: PanelCommands
    @FocusState private var focus: PanelFocus?
    @State private var whyExpanded = false
    /// The measured heights of the cards in a scrolling list (the viewport ends on a card boundary).
    @State private var cardHeights: [DisplayKey: CGFloat] = [:]
    @Environment(\.overbright) private var theme

    /// The panel over `services`. `symbol` draws the status symbol (the shell's code-drawn template); `close` closes
    /// the panel before an action opens another window; `takesFocus` puts keyboard focus on the master switch (the
    /// panel was opened by keyboard or VoiceOver); `expandsWhy` opens with the "Why?" row expanded (snapshots; it also
    /// starts expanded when no display can show extra brightness, DESIGN.md §5.11).
    public init(services: OverbrightServices, symbol: @escaping (StatusSymbolState) -> Image = { _ in Image(symbol: .sunMax) },
                takesFocus: Bool = false, expandsWhy: Bool = false, close: @escaping @MainActor () -> Void = {}) {
        self.services = services
        let nothingCapable = PanelContent(status: services.boost.status, tipShown: true, calibrated: [],
                                          fillLightOn: false, hasBattery: false).showsNothingCapable
        _whyExpanded = State(initialValue: expandsWhy || nothingCapable)
        self.symbol = symbol
        self.takesFocus = takesFocus
        commands = PanelCommands(services: services, source: .panel, close: close)
    }

    /// The panel's sections now.
    var content: PanelContent {
        let calibrated = Set(services.settings[DisplaySettings.perDisplay].filter { $0.value.calibration != nil }.keys)
        return PanelContent(status: services.boost.status,
                            tipShown: services.settings[OnboardingSettings.calibrationTipShown],
                            calibrated: calibrated, fillLightOn: services.fillLight.isOn,
                            hasBattery: services.signals.snapshot.power.batteryPercent != nil)
    }

    public var body: some View {
        let status = services.boost.status
        let content = content
        let titles = CardTitles.titles(for: status.displays)
        VStack(spacing: 0) {
            PanelHeader(status: status, fillLightOn: services.fillLight.isOn, symbol: symbol, commands: commands,
                        focus: $focus)
                .equatable()
            Divider()
            VStack(spacing: PanelLayout.cardGap) {
                if let banner = status.banner { bannerView(banner, status: status) }
                if let tip = content.calibrationTip {
                    CalibrationTipCard(display: tip, title: titles[tip] ?? "", commands: commands, focus: $focus)
                }
                cardList(content, status: status, titles: titles)
            }
            .padding(PanelLayout.outerPadding)
            .animation(theme.animation(status.banner == nil ? .bannerOut : .bannerIn), value: status.banner)
            Divider()
            footer(content, status: status)
                .padding(.horizontal, PanelLayout.outerPadding)
        }
        .frame(width: PanelLayout.width)
        .onKeyPress(.tab, phases: .down) { press in
            let order = focusOrder(content, status: status)
            focus = press.modifiers.contains(.shift) ? order.previous(before: focus) : order.next(after: focus)
            return .handled
        }
        .onKeyPress(keys: [.upArrow, .downArrow], phases: .down) { press in
            guard let target = focusOrder(content, status: status).slider(from: focus, down: press.key == .downArrow)
            else { return .ignored }
            focus = target
            return .handled
        }
        .onAppear { if takesFocus { focus = .masterSwitch } }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: "Overbright"))
    }

    // MARK: Sections

    /// The banner of `banner`, naming the display a stop happened on by its card title (DESIGN.md §12.3).
    static func bannerModel(_ banner: Banner, status: BoostStatus) -> BannerModel {
        BannerModel.make(banner, displayNames: CardTitles.titles(for: status.displays), in: .app)
    }

    private func bannerView(_ banner: Banner, status: BoostStatus) -> some View {
        let action = BannerAction.primary(for: banner)
        let commands = commands
        var primary: (() -> Void)?
        var activate: (@MainActor () -> Void)?
        if let action {
            primary = { action.perform(commands) }
            activate = { action.perform(commands) }
        }
        return PausedBanner(Self.bannerModel(banner, status: status), primary: primary)
            .panelFocus($focus, .bannerPrimary, cornerRadius: Radius.card, activate: activate ?? {})
            .transition(theme.reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
    }

    @ViewBuilder
    private func cardList(_ content: PanelContent, status: BoostStatus, titles: [DisplayKey: String]) -> some View {
        let inputs = DisplayCardModel.Inputs(services: services, status: status)
        let list = VStack(spacing: PanelLayout.cardGap) {
            if content.showsFillLightCard { FillLightCard(services: services, focus: $focus) }
            if content.showsNothingCapable {
                Text(verbatim: PanelText.nothingCapable)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(content.cards, id: \.key) { display in
                let model = DisplayCardModel(status: display, isMasterOn: status.isOn, services: services, inputs: inputs)
                DisplayCardView(model: model,
                                guardText: DisplayCardView.guardText(for: model, status: display, isMasterOn: status.isOn,
                                                                     boost: status),
                                status: display, isMasterOn: status.isOn, services: services, title: titles[display.key],
                                focus: $focus, commands: commands)
                    .equatable()
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { cardHeights[display.key] = $0 }
            }
            if !content.nonCapable.isEmpty {
                NonCapableRow(displays: content.nonCapable, titles: titles, isExpanded: $whyExpanded,
                              commands: commands, focus: $focus)
            }
        }
        if content.cards.count > PanelLayout.visibleCardsBeforeScrolling {
            // Three whole cards and a faded peek of the next (a scroll cue, never a card cut through its slider); the
            // list gives way first when the panel's height cap binds, so the footer always shows.
            let heights = content.cards.prefix(PanelLayout.visibleCardsBeforeScrolling).compactMap { cardHeights[$0.key] }
            ScrollView { list.padding(.bottom, PanelLayout.scrollPeek) }
                .mask { PanelScrollFade() }
                .frame(maxHeight: PanelLayout.scrollingListHeight(cardHeights: heights))
                .layoutPriority(-1)
        } else {
            // The list's own height while it fits (a scroll view's ideal height is its content's), scrolling once the
            // panel's height cap binds. Its bottom is inset by the focus ring's outset inside and out, so the scroll
            // view clips no ring of the last row ("Why?"), and nothing bounces while everything fits.
            ScrollView { list.padding(.bottom, Radius.focusRingOutset) }
                .padding(.bottom, -Radius.focusRingOutset)
                .scrollBounceBehavior(.basedOnSize)
        }
    }

    @ViewBuilder
    private func footer(_ content: PanelContent, status: BoostStatus) -> some View {
        if status.autoOffAt != nil {
            TimelineView(.everyMinute) { _ in footerRow(content, status: status) }
        } else {
            footerRow(content, status: status)
        }
    }

    private func footerRow(_ content: PanelContent, status: BoostStatus) -> some View {
        PanelFooter(chips: FooterChips.chips(settings: services.settings, hasBattery: content.showsBatteryChip,
                                             autoOffAt: status.autoOffAt, now: services.time.wallClock,
                                             editApps: { commands.openSettings(SettingsLinks.pausedApps) }),
                    focus: $focus)
            .equatable()
    }

    // MARK: Keyboard

    /// The Tab order of what is shown now.
    func focusOrder(_ content: PanelContent, status: BoostStatus) -> PanelFocusOrder {
        let cards = content.cards.map { display in
            let model = cardModel(display, status: status)
            return PanelFocusOrder.Card(key: display.key,
                                        hasChip: CardChip.model(for: model, isMasterOn: status.isOn) != nil,
                                        hasTurnOn: model.chipReason == .boostNotEnabled)
        }
        let rows = whyExpanded ? content.nonCapable.map { display in
            PanelFocusOrder.WhyRow(key: display.key,
                                   hasFix: display.decision.map { CardChip.verdictFix($0.eligibility.verdict) != nil } ?? false)
        } : []
        return PanelFocusOrder(cards: cards, hasWhy: !content.nonCapable.isEmpty, whyRows: rows,
                               bannerButtons: status.banner.flatMap(BannerAction.primary(for:)) == nil ? 0 : 1,
                               hasTip: content.calibrationTip != nil, hasBatteryChip: content.showsBatteryChip,
                               hasFillLightCard: content.showsFillLightCard)
    }

    private func cardModel(_ display: DisplayStatus, status: BoostStatus) -> DisplayCardModel {
        DisplayCardModel(status: display, isMasterOn: status.isOn, services: services)
    }
}

#Preview("Panel · boosting") {
    let services = ScriptedStatuses.services(named: "boosting") ?? OverbrightServices.preview()
    PanelView(services: services)
        .overbrightThemeRoot()
}

#Preview("Panel · banner and chips") {
    let services = ScriptedStatuses.services(named: "banner-battery") ?? OverbrightServices.preview()
    PanelView(services: services)
        .overbrightThemeRoot()
}
