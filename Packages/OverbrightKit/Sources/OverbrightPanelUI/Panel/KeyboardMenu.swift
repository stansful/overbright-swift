// OverbrightPanelUI/Panel/KeyboardMenu.swift — the panel's SwiftUI menus as AppKit menu items, for opening them from
// the keyboard at a `MenuAnchor` (Space or Return on a focused footer chip, the "⋯" button or the Fill Light card's
// display pop-up; DESIGN.md §5.12, §15). The rows, titles, checkmarks and actions are the same models the pointer's
// menus draw, so both paths always offer the same items.
import AppKit
import OverbrightCore
import OverbrightDesign

/// AppKit menu items built from the panel's menu models.
enum KeyboardMenu {
    /// A footer chip's rows (`GuardChipMenuItem`), submenus included.
    static func items(_ rows: [GuardChipMenuItem]) -> [NSMenuItem] {
        rows.map { row in
            switch row {
            case let .item(title, isChecked, perform):
                return ActionMenuItem.make(title, isChecked: isChecked, handler: perform)
            case let .submenu(title, children):
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                let submenu = NSMenu(title: title)
                submenu.autoenablesItems = false
                for child in items(children) { submenu.addItem(child) }
                item.submenu = submenu
                return item
            case .separator:
                return .separator()
            }
        }
    }

    /// The "⋯" menu's rows; `perform` runs a row (the same function the SwiftUI menu calls).
    static func items(_ rows: [OverflowItem], perform: @escaping @MainActor (OverflowItem) -> Void) -> [NSMenuItem] {
        rows.map { row in
            guard row != .separator else { return .separator() }
            return ActionMenuItem.make(row.title, isChecked: row.isChecked, keyEquivalent: row.keyEquivalent) {
                perform(row)
            }
        }
    }

    /// One row per choice, the selected one checked (the Fill Light card's display pop-up).
    static func choices<Value: Hashable>(_ choices: [(value: Value, title: String)], selected: Value?,
                                         choose: @escaping @MainActor (Value) -> Void) -> [NSMenuItem] {
        choices.map { choice in
            ActionMenuItem.make(choice.title, isChecked: choice.value == selected) { choose(choice.value) }
        }
    }
}
