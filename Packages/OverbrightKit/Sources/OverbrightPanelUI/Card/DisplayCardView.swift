// OverbrightPanelUI/Card/DisplayCardView.swift — one display's card in the panel (and in Welcome). DESIGN.md §5.4
// (title, slider row, readout, caption, chip line, context menu, VoiceOver actions on the card and on its slider, the
// switched-off boost half), §5.5 (the thumb shows the level the display has; moving it turns Overbright on; past the
// detent it turns extra brightness on, an OLED asks first and the thumb waits at Standard), §5.6, §5.7 (Space and Return
// open the chip's popover), §5.12 (⌃↩ opens the context menu); ARCHITECTURE.md §4.9.
// Seam written by WP0a (ARCHITECTURE.md §10.0): `init(status:isMasterOn:services:)` is fixed (Welcome uses it); the
// panel uses the internal initializer that adds its title, focus binding and commands, and hands it the model it built
// for the pass with the guard's words: such a card reads nothing observable itself and is `Equatable` on what it
// shows, so the panel's redraw skips a card whose model did not change (DESIGN.md §17: redraw on change only).
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
    /// The panel's model and guard words for this pass (nil: the card derives both from `status` in its body).
    private let given: Given?
    /// The level while the thumb moves (the engine stores the level; this keeps the thumb under the finger).
    @State private var dragLevel: LevelPosition?
    /// A move into the boost half that waits for the OLED notice (asked once, when the move ends).
    @State private var oledGate = OLEDBoostGate()
    /// The chip's popover is open (the keyboard opens it too).
    @State private var isChipPopoverShown = false
    @State private var menuAnchor = MenuAnchorReference()
    @Environment(\.panelMenuPresenter) private var menus

    /// A card for `status`; `services` gives the engine, settings and app control behind its actions.
    public init(status: DisplayStatus, isMasterOn: Bool, services: OverbrightServices) {
        self.init(status: status, isMasterOn: isMasterOn, services: services, title: nil, focus: nil,
                  commands: PanelCommands(services: services, source: .panel))
    }

    /// The panel's card: `title` tells identical names apart, `focus` joins the panel's Tab order.
    init(status: DisplayStatus, isMasterOn: Bool, services: OverbrightServices, title: String?,
         focus: FocusState<PanelFocus?>.Binding?, commands: PanelCommands) {
        self.status = status; self.isMasterOn = isMasterOn; self.services = services; self.title = title
        self.focus = focus; self.commands = commands; given = nil
    }

    /// The panel's card of `model`, built once for the pass with the guard's words `guardText`
    /// (`guardText(for:status:isMasterOn:boost:)`).
    init(model: DisplayCardModel, guardText: String?, status: DisplayStatus, isMasterOn: Bool,
         services: OverbrightServices, title: String?, focus: FocusState<PanelFocus?>.Binding?,
         commands: PanelCommands) {
        self.status = status; self.isMasterOn = isMasterOn; self.services = services; self.title = title
        self.focus = focus; self.commands = commands; given = Given(model: model, guardText: guardText)
    }

    /// What the panel hands a card for one pass.
    private struct Given: Equatable {
        let model: DisplayCardModel
        let guardText: String?
    }

    /// The card's derived state: the panel's, or derived from the services (observes the settings it reads).
    var model: DisplayCardModel {
        given?.model ?? DisplayCardModel(status: status, isMasterOn: isMasterOn, services: services)
    }

    public var body: some View {
        let model = model
        let shownTitle = title ?? model.name
        VStack(alignment: .leading, spacing: Space.s) {
            titleRow(shownTitle, linked: model.isLinked)
            sliderRow(model, name: shownTitle)
            readoutRow(model)
            chipLine(model)
        }
        .panelCard()
        .background(alignment: .topLeading) { MenuAnchor(reference: menuAnchor).frame(width: 1, height: 1) }
        .contextMenu { contextMenu(model) }
        .onKeyPress(.return, phases: .down) { press in
            guard press.modifiers == .control else { return .ignored }
            menus.present(menuAnchor, CardMenu.menuItems(for: model, lastDimLight: model.lastDimLight, contextMenu: true,
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
                .help(model.name)
                .accessibilityAddTraits(.isHeader)
        }
    }

    /// `sun.min`, the slider and `sun.max.fill` in exactly the card's inner width: 14 + 6 + 240 + 6 + 14 = 280 pt
    /// (DESIGN.md §5.4; the glyphs draw 16 and 17 pt wide at 14 pt, so each sits in a 14 × 14 frame).
    private func sliderRow(_ model: DisplayCardModel, name: String) -> some View {
        HStack(spacing: Space.s) {
            sliderGlyph(.sunMin)
            BoostSlider(level: levelBinding(model), top: model.top, allowedNow: model.allowedNow,
                        presets: model.presets, dimEnabled: model.dimEnabled, boostHalf: boostHalfState(model),
                        accessibilityName: name,
                        valueText: { LevelText.valueTag(at: $0, card: model, guardText: guardText(model)) },
                        onCommit: { commit($0, model) })
                .spokenValue { spokenValue(at: $0, model) }
                .extraRange(extraRange(model))
                .dimHalfReason(dimHalfReason(model))
                .dimmedLevel(LevelMapping.position(forDimLight: model.lastDimLight))
                .focusBinding(focus, equals: .slider(model.key))     // the slider's own element: one Tab stop, its keys
                // The card's context-menu items and chip actions on the element VoiceOver lands on (§5.5): outside the
                // control they attach to its one adjustable element.
                .accessibilityActions { accessibilityActions(model) }
                .frame(width: PanelLayout.trackWidth)
            sliderGlyph(.sunMaxFill)
        }
        .frame(width: PanelLayout.cardInnerWidth, alignment: .leading)
    }

    private func sliderGlyph(_ symbol: OverbrightSymbol) -> some View {
        Image(symbol: symbol)
            .font(.system(size: GlyphSize.sliderEnd))
            .foregroundStyle(.secondary)
            .frame(width: PanelLayout.sliderGlyph, height: PanelLayout.sliderGlyph)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func readoutRow(_ model: DisplayCardModel) -> some View {
        // One line of at most 200 pt: when a long translation does not fit, the preset name gives way to the numbers.
        ViewThatFits(in: .horizontal) {
            ReadoutText(model.readout)
            ReadoutText(Self.withoutPreset(model.readout))
        }
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

    /// The readout without its preset name (the fallback of a readout that does not fit its line).
    static func withoutPreset(_ values: ReadoutValues) -> ReadoutValues {
        var values = values
        values.preset = nil
        return values
    }

    @ViewBuilder
    private func chipLine(_ model: DisplayCardModel) -> some View {
        let chip = CardChip.model(for: model, isMasterOn: isMasterOn)
        let offersTurnOn = isMasterOn && model.chipReason == .boostNotEnabled
        if chip != nil || offersTurnOn {
            CardChipLine {
                if let chip {
                    StatusChip(chip, actions: CardChip.actions(for: model, isMasterOn: isMasterOn, commands: commands),
                               isPresented: $isChipPopoverShown)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .panelFocus(focus, .chip(model.key), cornerRadius: HitTarget.minimum.height / 2) {
                            isChipPopoverShown = true
                        }
                }
            } turnOn: {
                if offersTurnOn {
                    Button { commands.perform(.turnOnExtraBrightness, on: model) } label: {
                        Text(verbatim: CardAction.turnOnExtraBrightness.title)
                    }
                    .buttonStyle(OverbrightLinkButtonStyle())
                    .panelFocus(focus, .turnOn(model.key)) { commands.perform(.turnOnExtraBrightness, on: model) }
                }
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private func contextMenu(_ model: DisplayCardModel) -> some View {
        ForEach(Array(CardMenu.items(for: model, lastDimLight: model.lastDimLight, contextMenu: true).enumerated()),
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
        ForEach(Array(CardMenu.items(for: model, lastDimLight: model.lastDimLight, contextMenu: true).enumerated()),
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

    /// The thumb: under the finger while it moves, else the level the display shows (`displayedLevel`, so a display
    /// whose boost half is off or unavailable sits at Standard, as its readout says).
    private func levelBinding(_ model: DisplayCardModel) -> Binding<LevelPosition> {
        Binding(get: { dragLevel ?? model.displayedLevel }, set: { newValue in
            let turnsOn = newValue.isBoost && !model.boostEnabled && model.canBoost
            let waits = turnsOn && model.isOLED && !commands.preferences(of: model.key).oledNoticeAcknowledged
            let level = oledGate.move(to: newValue, waitsForNotice: waits)   // the thumb waits at Standard
            if turnsOn, !waits {
                commands.setExtraBrightness(true, for: model.key, name: model.name, isOLED: model.isOLED)
            }
            dragLevel = level
            services.boost.setLevel(level, for: model.isLinked ? nil : model.key, source: .panel)
        })
    }

    /// The end of a move. A move that ended in the boost half of an OLED display whose notice is unanswered asks now
    /// and, on Turn On, sets the level it was released at; one released at Standard or below asks nothing.
    private func commit(_ level: LevelPosition, _ model: DisplayCardModel) {
        dragLevel = nil
        let target: DisplayKey? = model.isLinked ? nil : model.key
        if let released = oledGate.release() {
            guard commands.setExtraBrightness(true, for: model.key, name: model.name, isOLED: model.isOLED) else { return }
            services.boost.setLevel(released, for: target, source: .panel)
            return
        }
        services.boost.setLevel(level, for: target, source: .panel)
    }

    /// VoiceOver's value of `position`: the guard's words while one holds the boost half (as the value tag shows),
    /// else the spoken canonical value ("Bright room, about 1.29 times, not calibrated").
    private func spokenValue(at position: LevelPosition, _ model: DisplayCardModel) -> String {
        if position.isBoost, let guardText = guardText(model), !guardText.isEmpty { return guardText }
        return LevelText.accessibilityValue(at: position, card: model)
    }

    /// The allowed-now marker's help tag and VoiceOver "Extra range", with the display's Peak figure, while extra
    /// light is on screen with a reading.
    private func extraRange(_ model: DisplayCardModel) -> ValueText? {
        guard case .active = model.boostHalf, let allowed = model.allowedNow else { return nil }
        return ValueText.extraRange(allowed: allowed, peak: model.peakTop)
    }

    /// Why the dim half is off (the verdict's sentence), for its help tag and VoiceOver hint.
    private func dimHalfReason(_ model: DisplayCardModel) -> String? {
        guard !model.dimEnabled, let verdict = model.verdict else { return nil }
        return VerdictText.make(verdict, advisories: model.advisories, lastGrant: nil).sentence
    }

    /// The guard that holds the boost half, in the HUD's words ("Paused: Low Power Mode"), for the value tag: the
    /// panel's for this pass, else read now.
    private func guardText(_ model: DisplayCardModel) -> String? {
        if let given { return given.guardText }
        return Self.guardText(for: model, status: status, isMasterOn: isMasterOn, boost: services.boost.status)
    }

    /// The guard that holds the boost half of `status`'s card `model`, in the HUD's words over the engine's `boost`.
    static func guardText(for model: DisplayCardModel, status: DisplayStatus, isMasterOn: Bool,
                          boost: BoostStatus) -> String? {
        guard model.boostHalf == .inactive, isMasterOn, let reasons = status.decision?.reasons,
              let reason = reasons.first(where: { $0 != .masterOff && ($0.blocksBoostOnly || $0.isGlobal) }) else {
            return nil
        }
        let change = LevelChange(sequence: 0, kind: .blocked(reason), source: .panel, display: status.key)
        return HUDText.make(change, status: boost)?.reason
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
}

extension DisplayCardView: Equatable {
    /// A panel card draws the same as another when the panel gave both the same model, guard words, title and master
    /// switch; the services, commands and focus binding are the panel's own for its life. A card that derives its
    /// model in its body never compares equal, so it always redraws.
    public static func == (lhs: DisplayCardView, rhs: DisplayCardView) -> Bool {
        guard let left = lhs.given, let right = rhs.given else { return false }
        return left == right && lhs.title == rhs.title && lhs.isMasterOn == rhs.isMasterOn
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
