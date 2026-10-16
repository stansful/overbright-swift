// OverbrightPanelUI/Card/DisplayCardView.swift — one display's card in the panel (and in Welcome). DESIGN.md §5.4
// (title, slider row, readout, caption, chip line, context menu, VoiceOver actions, the switched-off boost half),
// §5.5 (moving the thumb turns Overbright on; past the detent it turns extra brightness on, an OLED asks first and the
// thumb waits at Standard), §5.6, §5.7, §5.12 (⌃↩ opens the context menu); ARCHITECTURE.md §4.9.
// Seam written by WP0a (ARCHITECTURE.md §10.0): `init(status:isMasterOn:services:)` is fixed (Welcome uses it); the
// panel uses the internal initializer that adds its title, focus binding and commands.
import OverbrightCore
import OverbrightDesign
import OverbrightPolicy
import SwiftUI

/// The card of one display that can boost or dim.
public struct DisplayCardView: View {
    private let status: DisplayStatus
    private let isMasterOn: Bool
    private let services: OverbrightServices
    private let title: String?
    private let focus: FocusState<PanelFocus?>.Binding?
    private let commands: PanelCommands
    @Environment(\.overbright) private var theme
    /// The level while the thumb moves (the engine stores the level; this keeps the thumb under the finger).
    @State private var dragLevel: LevelPosition?
    /// A boost level that waits for the OLED notice, asked once when the drag ends.
    @State private var pendingBoost: LevelPosition?
    @State private var menuAnchor = MenuAnchorReference()

    /// A card for `status`; `services` gives the engine, settings and app control behind its actions.
    public init(status: DisplayStatus, isMasterOn: Bool, services: OverbrightServices) {
        self.init(status: status, isMasterOn: isMasterOn, services: services, title: nil, focus: nil,
                  commands: PanelCommands(services: services, source: .panel))
    }

    /// The panel's card: `title` tells identical names apart, `focus` joins the panel's Tab order.
    init(status: DisplayStatus, isMasterOn: Bool, services: OverbrightServices, title: String?,
         focus: FocusState<PanelFocus?>.Binding?, commands: PanelCommands) {
        self.status = status; self.isMasterOn = isMasterOn; self.services = services; self.title = title
        self.focus = focus; self.commands = commands
    }

    /// The card's derived state (observes the settings it reads).
    var model: DisplayCardModel { DisplayCardModel(status: status, isMasterOn: isMasterOn, services: services) }

    public var body: some View {
        let model = model
        let shownTitle = title ?? status.name
        VStack(alignment: .leading, spacing: Space.s) {
            titleRow(shownTitle, linked: model.isLinked)
            sliderRow(model, name: shownTitle)
            readoutRow(model)
            chipLine(model)
        }
        .padding(PanelLayout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topLeading) { MenuAnchor(reference: menuAnchor).frame(width: 1, height: 1) }
        .background(cardFill, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
            .strokeBorder(cardStroke, lineWidth: StrokeWidth.regular))
        .contextMenu { contextMenu(model) }
        .onKeyPress(.return, phases: .down) { press in
            guard press.modifiers == .control else { return .ignored }
            menuAnchor.popUp(CardMenu.menuItems(for: model, lastDimLight: lastDimLight, contextMenu: true,
                                                commands: commands))
            return .handled
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: shownTitle))
        .accessibilityActions { accessibilityActions(model) }
    }

    // MARK: Rows

    private func titleRow(_ text: String, linked: Bool) -> some View {
        HStack(spacing: Space.xs) {
            if linked {
                Image(symbol: .link)
                    .foregroundStyle(.secondary)
                    .help(PanelText.linkedHelp)
                    .accessibilityLabel(Text(verbatim: PanelText.linkedHelp))
            }
            Text(verbatim: text)
                .font(.headline)
                .lineLimit(2)
                .truncationMode(.tail)
                .help(status.name)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func sliderRow(_ model: DisplayCardModel, name: String) -> some View {
        HStack(spacing: Space.s) {
            Image(symbol: .sunMin)
                .font(.system(size: PanelLayout.sliderGlyph))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            BoostSlider(level: levelBinding(model), top: model.top, allowedNow: model.allowedNow,
                        presets: model.presets, dimEnabled: model.dimEnabled, boostHalf: boostHalfState(model),
                        accessibilityName: name,
                        valueText: { LevelText.valueTag(at: $0, card: model, guardText: guardText(model)) },
                        onCommit: { commit($0, model) })
                .frame(width: PanelLayout.trackWidth)
                .panelFocus(focus, .slider(model.key))
            Image(symbol: .sunMaxFill)
                .font(.system(size: PanelLayout.sliderGlyph))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func readoutRow(_ model: DisplayCardModel) -> some View {
        ReadoutText(model.readout)
            .lineLimit(1)
            .frame(maxWidth: PanelLayout.readoutWidth, alignment: .leading)
            .help(model.readout.isEstimate ? PanelText.readoutHelp + "\n" + PanelText.notCalibratedHelp
                  : PanelText.readoutHelp)
        if model.isCompatibilityMode {
            Text(verbatim: PanelText.compatibilityMode)
                .font(.caption)
                .foregroundStyle(.secondary)
                .help(PanelText.compatibilityFootnote)
        }
    }

    @ViewBuilder
    private func chipLine(_ model: DisplayCardModel) -> some View {
        if let chip = CardChip.model(for: model, isMasterOn: isMasterOn) {
            HStack(spacing: Space.s) {
                StatusChip(chip, actions: CardChip.actions(for: model, isMasterOn: isMasterOn, commands: commands))
                    .frame(maxWidth: PanelLayout.cardInnerWidth, alignment: .leading)
                    .panelFocus(focus, .chip(model.key), cornerRadius: HitTarget.minimum.height / 2)
                if model.chipReason == .boostNotEnabled {
                    Button { commands.perform(.turnOnExtraBrightness, on: model) } label: {
                        Text(verbatim: CardAction.turnOnExtraBrightness.title)
                    }
                    .buttonStyle(OverbrightDesign.LinkButtonStyle())
                    .panelFocus(focus, .turnOn(model.key)) { commands.perform(.turnOnExtraBrightness, on: model) }
                }
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private func contextMenu(_ model: DisplayCardModel) -> some View {
        ForEach(Array(CardMenu.items(for: model, lastDimLight: lastDimLight, contextMenu: true).enumerated()),
                id: \.offset) { _, item in
            if item == .separator {
                Divider()
            } else if item == .noExtraBrightness {
                Text(verbatim: CardMenu.title(of: item, card: model) ?? "")
            } else {
                Toggle(isOn: Binding(get: { CardMenu.isChecked(item) },
                                     set: { _ in CardMenu.perform(item, card: model, commands: commands) })) {
                    Text(verbatim: CardMenu.title(of: item, card: model) ?? "")
                }
            }
        }
    }

    @ViewBuilder
    private func accessibilityActions(_ model: DisplayCardModel) -> some View {
        ForEach(Array(CardMenu.items(for: model, lastDimLight: lastDimLight, contextMenu: true).enumerated()),
                id: \.offset) { _, item in
            if let title = CardMenu.title(of: item, card: model), item != .noExtraBrightness {
                Button { CardMenu.perform(item, card: model, commands: commands) } label: { Text(verbatim: title) }
            }
        }
        ForEach(CardChip.kinds(for: model, isMasterOn: isMasterOn), id: \.self) { action in
            Button { commands.perform(action, on: model) } label: { Text(verbatim: action.title) }
        }
    }

    // MARK: Level

    private var lastDimLight: Double { services.settings[DisplaySettings.lastDimLight] }

    private func levelBinding(_ model: DisplayCardModel) -> Binding<LevelPosition> {
        Binding(get: { dragLevel ?? model.level }, set: { newValue in
            var level = newValue
            if level.isBoost, !model.boostEnabled, model.canBoost {
                if model.isOLED, !commands.preferences(of: model.key).oledNoticeAcknowledged {
                    pendingBoost = level                       // the thumb waits at Standard until the notice
                    level = .standard
                } else {
                    commands.setExtraBrightness(true, for: model.key, name: model.name, isOLED: model.isOLED)
                }
            }
            dragLevel = level
            services.boost.setLevel(level, for: model.isLinked ? nil : model.key, source: .panel)
        })
    }

    private func commit(_ level: LevelPosition, _ model: DisplayCardModel) {
        dragLevel = nil
        let target: DisplayKey? = model.isLinked ? nil : model.key
        if let pending = pendingBoost {
            pendingBoost = nil
            guard commands.setExtraBrightness(true, for: model.key, name: model.name, isOLED: model.isOLED) else { return }
            services.boost.setLevel(pending, for: target, source: .panel)
            return
        }
        services.boost.setLevel(level, for: target, source: .panel)
    }

    /// The guard that holds the boost half, in the HUD's words ("Paused: Low Power Mode"), for the value tag.
    private func guardText(_ model: DisplayCardModel) -> String? {
        guard model.boostHalf == .inactive, isMasterOn, let reasons = status.decision?.reasons,
              let reason = reasons.first(where: { $0 != .masterOff && ($0.blocksBoostOnly || $0.isGlobal) }) else {
            return nil
        }
        let change = LevelChange(sequence: 0, kind: .blocked(reason), source: .panel, display: status.key)
        return HUDText.make(change, status: services.boost.status)?.reason
    }

    private func boostHalfState(_ model: DisplayCardModel) -> BoostHalfState {
        switch model.boostHalf {
        case .active: .active
        case .inactive: .inactive
        case .switchedOff: .switchedOff
        case .unavailable(.verdict(let verdict)):
            .unavailable(reason: VerdictText.make(verdict, advisories: model.advisories, lastGrant: nil).sentence)
        case .unavailable(.safeLimitReached): .unavailable(reason: PanelText.safeLimitReached)
        case .unavailable(.littleGain): .unavailable(reason: PanelText.littleGain)
        }
    }

    // MARK: Colours (system colours of DESIGN.md §2.1's `card` and `cardStroke`)

    private var cardFill: Color {
        theme.palette == .highContrast ? Color(nsColor: .controlBackgroundColor) : Color(nsColor: .quaternarySystemFill)
    }

    private var cardStroke: Color {
        theme.palette == .highContrast ? Color(nsColor: .separatorColor) : Color(nsColor: .separatorColor).opacity(0.5)
    }
}

#Preview("Display card · boosting") {
    let services = OverbrightServices.preview()
    let status = ScriptedStatuses.status(named: "boosting")?.displays.first
        ?? DisplayStatus(key: DisplayFixture.Keys.builtIn, name: "Built-in Display", phase: .idle, decision: nil,
                         appliedGain: 1, appliedFactor: 1, mechanism: .table, strategy: nil, lastReading: nil,
                         sdrWhite: nil)
    DisplayCardView(status: status, isMasterOn: true, services: services)
        .frame(width: PanelLayout.cardWidth)
        .padding()
        .overbrightThemeRoot()
}
