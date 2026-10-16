// OverbrightAppShell/StatusItem/ClickRouting.swift — what a click on the status item does. DESIGN.md §4.2 (the table:
// click, right-click or ⌃-click, ⌥-click, for each "Clicking the icon" setting); D13. Pure, so `ClickRoutingTests`
// cover every row without an event.
import AppKit
import OverbrightCore

/// The status item's click table.
enum ClickRouting {
    /// The mouse button.
    enum Button: Equatable { case left, right }

    /// What the click does.
    enum Action: Equatable {
        /// Opens the panel, or closes it when it is open.
        case togglePanel
        /// Turns Overbright on or off.
        case toggleMaster
        /// Opens the menu.
        case showMenu
    }

    /// The action of a click with `button` and `modifiers` under the "Clicking the icon" setting.
    static func action(for button: Button, modifiers: NSEvent.ModifierFlags, setting: StatusClickAction) -> Action {
        if button == .right || modifiers.contains(.control) { return .showMenu }
        let primary: Action = setting == .openPanel ? .togglePanel : .toggleMaster
        let alternate: Action = setting == .openPanel ? .toggleMaster : .togglePanel
        return modifiers.contains(.option) ? alternate : primary
    }

    /// The action of `event` (a mouse-up on the status button); a click without a mouse event (VoiceOver's press,
    /// the keyboard) is a plain left click.
    static func action(for event: NSEvent?, setting: StatusClickAction) -> Action {
        let button: Button = event?.type == .rightMouseUp || event?.type == .rightMouseDown ? .right : .left
        let modifiers = event?.modifierFlags.intersection(.deviceIndependentFlagsMask) ?? []
        return action(for: button, modifiers: modifiers, setting: setting)
    }

    /// The click came from the keyboard or VoiceOver (no mouse event): the panel then takes keyboard focus.
    static func isKeyboardOrAccessibility(_ event: NSEvent?) -> Bool {
        guard let event else { return true }
        switch event.type {
        case .leftMouseUp, .leftMouseDown, .rightMouseUp, .rightMouseDown, .otherMouseUp, .otherMouseDown: return false
        default: return true
        }
    }
}
