// OverbrightPanelUI/Panel/PanelView.swift — the panel's content: header, Fill Light card, banner, calibration tip, the
// empty-state sentence, one card per display that can boost or dim, the "Why?" row, footer chips. DESIGN.md §5.1–§5.12
// (the card list scrolls beyond the height cap or from four displays on; header, banner and footer stay), §2.0 rule 3
// (the shell's hosting view applies `.overbrightThemeRoot` once). The window, its glass and its placement are the
// shell's (`PanelController`).
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
    @Environment(\.overbright) private var theme

    /// The panel over `services`. `symbol` draws the status symbol (the shell's code-drawn template); `close` closes
    /// the panel before an action opens another window; `takesFocus` puts keyboard focus on the master switch (the
    /// panel was opened by keyboard or VoiceOver); `expandsWhy` opens with the "Why?" row expanded (snapshots).
    public init(services: OverbrightServices, symbol: @escaping (StatusSymbolState) -> Image = { _ in Image(symbol: .sunMax) },
                takesFocus: Bool = false, expandsWhy: Bool = false, close: @escaping @MainActor () -> Void = {}) {
        self.services = services
        _whyExpanded = State(initialValue: expandsWhy)
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
                .padding(.horizontal, Space.l)
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

    private func bannerView(_ banner: Banner, status: BoostStatus) -> some View {
        let action = BannerAction.primary(for: banner)
        let commands = commands
        var primary: (() -> Void)?
        var activate: (@MainActor () -> Void)?
        if let action {
            primary = { action.perform(commands, status: status) }
            activate = { action.perform(commands, status: status) }
        }
        return PausedBanner(BannerModel.make(banner), primary: primary, secondary: nil)
            .panelFocus($focus, .bannerPrimary, cornerRadius: Radius.card, activate: activate)
            .transition(theme.reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
    }

    @ViewBuilder
    private func cardList(_ content: PanelContent, status: BoostStatus, titles: [DisplayKey: String]) -> some View {
        let list = VStack(spacing: PanelLayout.cardGap) {
            if content.showsFillLightCard { FillLightCard(services: services, focus: $focus) }
            if content.showsNothingCapable {
                Text(verbatim: PanelText.nothingCapable)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(content.cards, id: \.key) { display in
                DisplayCardView(status: display, isMasterOn: status.isOn, services: services, title: titles[display.key],
                                focus: $focus, commands: commands)
            }
            if !content.nonCapable.isEmpty {
                NonCapableRow(displays: content.nonCapable, titles: titles, isExpanded: $whyExpanded,
                              commands: commands, focus: $focus)
            }
        }
        if content.cards.count > PanelLayout.visibleCardsBeforeScrolling {
            ScrollView { list }
                .frame(height: PanelLayout.scrollingListHeight)
        } else {
            ViewThatFits(in: .vertical) {
                list
                ScrollView { list }
            }
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
