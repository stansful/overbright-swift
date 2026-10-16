// OverbrightPanelUI/Panel/ActionMenuItem.swift — `NSMenuItem`s that run a closure, for the AppKit menus built from
// PanelUI's row models: the card's context menu opened with ⌃↩ (DESIGN.md §5.12), the status menu and the Dock menu
// (the shell). Menus cannot be rendered in tests; their rows are models (`CardMenuItem`, the shell's menu rows).
import AppKit

/// Menu items with closure actions.
public enum ActionMenuItem {
    /// An enabled item titled `title` that runs `handler`; `isChecked` draws the checkmark. The item keeps its
    /// handler alive (`representedObject`), because `NSMenuItem.target` is weak.
    public static func make(_ title: String, isChecked: Bool = false, keyEquivalent: String = "",
                            handler: @escaping @MainActor () -> Void) -> NSMenuItem {
        let target = MenuActionTarget(handler: handler)
        let item = NSMenuItem(title: title, action: #selector(MenuActionTarget.run(_:)), keyEquivalent: keyEquivalent)
        item.target = target
        item.representedObject = target
        item.state = isChecked ? .on : .off
        return item
    }

    /// A disabled row (a status line).
    public static func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    /// Runs the action of `item` (tests and QA: menus cannot be clicked without synthesized input).
    public static func run(_ item: NSMenuItem) {
        (item.representedObject as? MenuActionTarget)?.run(nil)
    }
}

/// The target of an `ActionMenuItem`.
final class MenuActionTarget: NSObject {
    private let handler: @MainActor () -> Void

    init(handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        super.init()
    }

    @objc func run(_ sender: Any?) { handler() }
}
