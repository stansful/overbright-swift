// OverbrightAppShell/StatusItem/StatusMenuRender.swift — the status menu's rows as an `NSMenu` whose items act through
// the engine and `PanelCommands` (source `.menu`, so the HUD never shows for them). DESIGN.md §4.3; ARCHITECTURE.md
// §4.9 (pause and resume are the engine's), §7.6.
import AppKit
import Foundation
import OverbrightCore
import OverbrightPanelUI

/// Turns `StatusMenuModel` rows into AppKit menu items.
enum StatusMenuRender {
    /// The pause length of "Pause for 1 Hour".
    static let pauseLength: TimeInterval = 3600

    /// The menu for `model`; `showPanel` opens the panel (toggle mode's first row).
    static func menu(_ model: StatusMenuModel, services: OverbrightServices,
                     showPanel: @escaping @MainActor () -> Void) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let commands = PanelCommands(services: services, source: .menu)
        for row in model.rows { menu.addItem(item(row, model: model, services: services, commands: commands,
                                                  showPanel: showPanel)) }
        return menu
    }

    /// The row's title.
    static func title(of row: StatusMenuRow) -> String {
        switch row {
        case .status(let sentence): sentence
        case .bannerAction(let action): StatusMenuText.title(of: titleKind(action))
        case .showPanel: StatusMenuText.showPanel
        case .separator: "---"
        case .master(let isOn, _): isOn ? StatusMenuText.turnOff : StatusMenuText.turnOn
        case .dimAll(let isDimmed, _): isDimmed ? StatusMenuText.stopDimming : StatusMenuText.dimAll
        case .display(_, let title, _): title
        case .allDisplays: StatusMenuText.allDisplays
        case .pause: StatusMenuText.pauseForAnHour
        case .pausedUntil(let date): StatusMenuText.pausedUntil(date.formatted(date: .omitted, time: .shortened))
        case .resume: StatusMenuText.resume
        case .fillLight: StatusMenuText.fillLight
        case .updateAvailable(let version, _): StatusMenuText.updateAvailable(version)
        case .settings: StatusMenuText.settings
        case .help: StatusMenuText.help
        case .quit: StatusMenuText.quit
        }
    }

    /// What `dump()` adds after a title: the key equivalent, a check, "(disabled)".
    static func suffix(of row: StatusMenuRow) -> String {
        switch row {
        case .status, .pausedUntil: " (disabled)"
        case .master(_, let key?), .dimAll(_, let key?): " " + key.displayText
        case .fillLight(true): " ✓"
        case .settings: " ⌘,"
        case .quit: " ⌘Q"
        default: ""
        }
    }

    /// The menu title kind of a banner action (title case, DESIGN.md §12.3).
    static func titleKind(_ action: BannerAction) -> StatusMenuText.BannerActionTitle {
        switch action {
        case .resume: .resume
        case .useCompatibilityMode: .useCompatibilityMode
        case .continueAnyway: .continueAnyway
        case .openDisplaySettings, .openFocusSettings: .openSystemSettings
        case .tryAgain: .tryAgain
        case .changePowerRules: .changePowerRules
        case .changeHours: .changeHours
        }
    }

    // MARK: Items

    private static func item(_ row: StatusMenuRow, model: StatusMenuModel, services: OverbrightServices,
                             commands: PanelCommands, showPanel: @escaping @MainActor () -> Void) -> NSMenuItem {
        let boost = services.boost
        let title = title(of: row)
        switch row {
        case .separator:
            return .separator()
        case .status, .pausedUntil:
            return ActionMenuItem.disabled(title)
        case .bannerAction(let action):
            return ActionMenuItem.make(title) { action.perform(commands, status: boost.status) }
        case .showPanel:
            return ActionMenuItem.make(title, handler: showPanel)
        case .master(let isOn, let key):
            let item = ActionMenuItem.make(title) { boost.setOn(!isOn, source: .menu) }
            MenuKeyEquivalent.apply(key, to: item)
            return item
        case .dimAll(_, let key):
            let item = ActionMenuItem.make(title) { boost.toggleDim(source: .menu) }
            MenuKeyEquivalent.apply(key, to: item)
            return item
        case .display(let key, _, _), .allDisplays(let key, _):
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let submenu = NSMenu(title: title)
            submenu.autoenablesItems = false
            if let card = model.cards[key] {
                let lastDimLight = services.settings[DisplaySettings.lastDimLight]
                for entry in CardMenu.menuItems(for: card, lastDimLight: lastDimLight, contextMenu: false,
                                                commands: commands) {
                    submenu.addItem(entry)
                }
            }
            item.submenu = submenu
            return item
        case .pause:
            let time = services.time
            return ActionMenuItem.make(title) {
                boost.pause(until: time.wallClock.addingTimeInterval(pauseLength), source: .menu)
            }
        case .resume:
            return ActionMenuItem.make(title) { boost.resume(source: .menu) }
        case .fillLight(let isOn):
            return ActionMenuItem.make(title, isChecked: isOn) { services.fillLight.setOn(!isOn, source: .menu) }
        case .updateAvailable(_, let url):
            return ActionMenuItem.make(title) { NSWorkspace.shared.open(url) }
        case .settings:
            return ActionMenuItem.make(title, keyEquivalent: ",") { commands.openSettings(nil) }
        case .help:
            return ActionMenuItem.make(title) { commands.showHelp(nil) }
        case .quit:
            return ActionMenuItem.make(title, keyEquivalent: "q") { commands.quit() }
        }
    }
}
