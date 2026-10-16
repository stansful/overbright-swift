// OverbrightPanelUI/Card/CardMenu+AppKit.swift — a display's quick-level rows as AppKit menu items: the status menu's
// per-display submenu and the card's context menu opened from the keyboard (⌃↩, DESIGN.md §5.12).
import AppKit

extension CardMenu {
    /// The rows of `card` as menu items that run through `commands`.
    public static func menuItems(for card: DisplayCardModel, lastDimLight: Double, contextMenu: Bool,
                                 commands: PanelCommands) -> [NSMenuItem] {
        items(for: card, lastDimLight: lastDimLight, contextMenu: contextMenu).map { item in
            switch item {
            case .separator:
                return NSMenuItem.separator()
            case .noExtraBrightness:
                return ActionMenuItem.disabled(title(of: item, card: card) ?? "")
            default:
                return ActionMenuItem.make(title(of: item, card: card) ?? "", isChecked: isChecked(item)) {
                    perform(item, card: card, commands: commands)
                }
            }
        }
    }

    /// Whether `item` draws a checkmark.
    public static func isChecked(_ item: CardMenuItem) -> Bool {
        switch item {
        case .level(_, let isChecked), .dimmed(_, let isChecked): isChecked
        default: false
        }
    }
}
