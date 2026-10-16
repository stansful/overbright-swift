// OverbrightPanelUI/Card/CardMenu.swift — the quick levels of one display: the card's context menu (also its
// VoiceOver actions) and the status menu's per-display submenu share these rows. DESIGN.md §4.3 (title case, AppKit
// chrome), §5.4 (context menu), §5.5 (only shown presets), §12.4 (OLED notice before turning extra brightness on).
import OverbrightCore
import OverbrightDesign
import OverbrightPolicy

/// One row of a display's quick-level menu.
public nonisolated enum CardMenuItem: Hashable, Sendable {
    /// Standard or a shown preset; checked when the display is at it.
    case level(LevelPreset, isChecked: Bool)
    /// The last dim level ("Dimmed · 25 %"), as light; checked when the display is at it.
    case dimmed(light: Double, isChecked: Bool)
    /// A disabled row: the display cannot boost ("No Extra Brightness on This Display").
    case noExtraBrightness
    /// A separator.
    case separator
    /// "Calibrate…" (context menu only).
    case calibrate
    /// "Settings for This Display…" (context menu only).
    case settingsForDisplay
    /// "Don't Use on This Display" (`false`) or "Use Extra Brightness on This Display" (`true`).
    case extraBrightness(turnOn: Bool)
    /// "Try Again" (context menu only, while failed).
    case tryAgain
}

/// The quick-level rows of a display and what each does.
public enum CardMenu {
    /// The rows for `card`. `lastDimLight` is the dim level of Dim All and the menus; `contextMenu` adds the card's
    /// own rows (Calibrate…, Settings for This Display…, Try Again).
    public static func items(for card: DisplayCardModel, lastDimLight: Double, contextMenu: Bool) -> [CardMenuItem] {
        var items: [CardMenuItem] = []
        let atStandard = abs(card.level.value) <= 0.02
        if card.canBoost {
            items.append(.level(.standard, isChecked: atStandard))
            for preset in card.presets {
                items.append(.level(preset, isChecked: card.boostEnabled && LevelMapping.preset(at: card.level) == preset))
            }
        } else {
            if card.dimEnabled { items.append(.level(.standard, isChecked: atStandard)) }
            items.append(.noExtraBrightness)
        }
        if card.dimEnabled {
            let current = card.level.isDim ? LevelMapping.dimLight(for: card.level) : nil
            let isChecked = current.map { abs($0 - lastDimLight) <= 0.005 } ?? false
            items += [.separator, .dimmed(light: lastDimLight, isChecked: isChecked)]
        }
        if contextMenu {
            items.append(.separator)
            if card.canCalibrate { items.append(.calibrate) }
            items.append(.settingsForDisplay)
        }
        if card.canBoost {
            if !contextMenu { items.append(.separator) }
            items.append(.extraBrightness(turnOn: !card.boostEnabled))
        }
        if contextMenu, card.isFailed { items.append(.tryAgain) }
        return items
    }

    /// The row's title (title case), nil for a separator.
    public static func title(of item: CardMenuItem, card: DisplayCardModel) -> String? {
        switch item {
        case .level(let preset, _): MenuTitles.level(preset)
        case .dimmed(let light, _):
            ValueText.make(LevelText.values(at: LevelMapping.position(forDimLight: light), top: card.top,
                                            presets: card.presets, base: card.readout)).text
        case .noExtraBrightness: MenuTitles.noExtraBrightness
        case .separator: nil
        case .calibrate: MenuTitles.calibrate
        case .settingsForDisplay: MenuTitles.settingsForDisplay
        case .extraBrightness(let turnOn): turnOn ? MenuTitles.useExtraBrightness : MenuTitles.dontUse
        case .tryAgain: MenuTitles.tryAgain
        }
    }

    /// Runs `item` for `card`'s display through `commands`.
    public static func perform(_ item: CardMenuItem, card: DisplayCardModel, commands: PanelCommands) {
        let services = commands.services
        let target: DisplayKey? = card.isLinked ? nil : card.key
        switch item {
        case .level(.standard, _):
            services.boost.setLevel(.standard, for: target, source: commands.source)
        case .level(let preset, _):
            if !card.boostEnabled {
                guard commands.setExtraBrightness(true, for: card.key, name: card.name, isOLED: card.isOLED) else { return }
            }
            services.boost.setExtraBrightness(.preset(preset), for: target, source: commands.source)
        case .dimmed(let light, _):
            services.boost.setDimLight(light, for: target, source: commands.source)
        case .calibrate:
            commands.calibrate(card.key)
        case .settingsForDisplay:
            commands.openSettings(SettingsLinks.display(card.key))
        case .extraBrightness(let turnOn):
            commands.setExtraBrightness(turnOn, for: card.key, name: card.name, isOLED: card.isOLED)
        case .tryAgain:
            services.boost.retry(card.key)
        case .noExtraBrightness, .separator:
            break
        }
    }
}
