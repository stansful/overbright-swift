// OverbrightAppShell/HUD/HUDContent.swift — what the HUD says and draws for one change on one display. DESIGN.md §1
// principle 4 (one value text on every surface), §3.3 ("the readout and the HUD show the target at once"), §6, §12.9.
// A level change shows the level the display is set to — its card's `displayedLevel`, the level the panel's thumb
// sits at — as both the value and the bar, in Design's words (`ValueText`), so the HUD never says "Standard" over a dim
// bar while the engine is still ramping, nor "Preparing…" in the value's place. Every other change is Design's
// `HUDText` (reasons, "Preparing…", automations).
import OverbrightCore
import OverbrightDesign
import OverbrightPanelUI
import OverbrightPolicy

/// The HUD's text and bar for a change.
enum HUDContent {
    /// The HUD for `change` shown about `display` (the change's own display, else the one under the pointer, else
    /// the first), with the settings and facts of `services`.
    static func text(for change: LevelChange, status: BoostStatus, on display: DisplayKey?,
                     services: OverbrightServices) -> HUDText? {
        guard case .level = change.kind else { return HUDText.make(change, status: status, on: display, in: .app) }
        let target = change.display ?? display ?? status.displays.first?.key
        let shown = status.displays.first { $0.key == target }
        let name = status.displays.count >= 2 ? shown?.name : nil
        let value: ValueText
        let state: ReadoutValues.State
        if status.isOn, let shown {
            let card = DisplayCardModel(status: shown, isMasterOn: true, services: services)
            let values = LevelText.values(at: card.displayedLevel, top: card.top, presets: card.presets,
                                          base: card.readout)
            value = ValueText.make(values)
            state = values.state
        } else if status.isOn {
            value = ValueText.make(ReadoutValues(state: .standard, appliedGain: 1, requestedGain: nil, nits: nil,
                                                 preset: nil, isEstimate: false, dimPercent: nil))
            state = .standard
        } else {
            value = ValueText(text: CommonNames.off(), accessibilityText: CommonNames.off())
            state = .off
        }
        let symbol: OverbrightSymbol = switch state {
        case .boost: .sunMaxFill
        case .dim: .sunMin
        case .preparing: .hourglass
        case .off, .standard: .sunMax
        }
        let announcement = name.map { CopyFormat.spokenParts($0, value.accessibilityText) } ?? value.accessibilityText
        return HUDText(symbol: symbol, displayName: name, value: value.text, reason: nil, announcement: announcement)
    }

    /// The level the bar draws for `display`: the level the display is set to (Standard while its boost half is off or
    /// unavailable), Standard while Overbright is off.
    static func level(of display: DisplayKey?, status: BoostStatus, services: OverbrightServices) -> LevelPosition {
        guard status.isOn, let shown = status.displays.first(where: { $0.key == display }) else { return .standard }
        return DisplayCardModel(status: shown, isMasterOn: true, services: services).displayedLevel
    }

    /// The display a change is shown about: its own, else the one under the pointer, else the first.
    static func shownDisplay(for change: LevelChange, underPointer: DisplayKey?, status: BoostStatus) -> DisplayKey? {
        change.display ?? underPointer.flatMap { key in status.displays.contains { $0.key == key } ? key : nil }
            ?? status.displays.first?.key
    }
}
