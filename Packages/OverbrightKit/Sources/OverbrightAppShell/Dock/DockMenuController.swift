// OverbrightAppShell/Dock/DockMenuController.swift — the optional Dock icon's menu and activation policy. DESIGN.md
// §4.4 (General ▸ Show in Dock, off by default; the menu offers Turn On / Turn Off Overbright, Dim All Displays / Stop
// Dimming, Back to Standard and Settings…, plus the system's Quit), §7.3; ARCHITECTURE.md §3.8
// (`GeneralSettings.showsDockIcon`), §7.4 (Back to Standard from the Dock menu). WP13 wires it: the app delegate's
// `applicationDockMenu(_:)` returns `menu()`, and `applyActivationPolicy()` runs at launch and when the setting
// changes (`start()` observes it).
import AppKit
import OverbrightCore
import OverbrightPanelUI
import os

private let log = Log.logger(.app)

/// One row of the Dock menu.
enum DockMenuRow: Equatable {
    /// Turn On / Turn Off Overbright.
    case master(isOn: Bool)
    /// Dim All Displays / Stop Dimming.
    case dimAll(isDimmed: Bool)
    /// Back to Standard.
    case backToStandard
    /// A separator.
    case separator
    /// Settings…
    case settings

    /// The rows for `status`.
    static func rows(for status: BoostStatus) -> [DockMenuRow] {
        [.master(isOn: status.isOn), .dimAll(isDimmed: DimState.isEveryDisplayDimmed(status)), .backToStandard,
         .separator, .settings]
    }

    /// The row's title.
    var title: String {
        switch self {
        case .master(let isOn): isOn ? StatusMenuText.turnOff : StatusMenuText.turnOn
        case .dimAll(let isDimmed): isDimmed ? StatusMenuText.stopDimming : StatusMenuText.dimAll
        case .backToStandard: StatusMenuText.backToStandard
        case .separator: "---"
        case .settings: StatusMenuText.settings
        }
    }
}

/// The Dock icon and its menu.
final class DockMenuController {
    private let services: OverbrightServices
    private var observation: ObservationToken?

    /// A controller for the app's services.
    init(services: OverbrightServices) { self.services = services }

    /// The activation policy for the setting: `.regular` shows the Dock icon, `.accessory` is the menu bar app.
    static func activationPolicy(showsDockIcon: Bool) -> NSApplication.ActivationPolicy {
        showsDockIcon ? .regular : .accessory
    }

    /// Applies the setting now and whenever it changes.
    func start() {
        applyActivationPolicy()
        let settings = services.settings
        observation = OverbrightCore.observe({ settings[GeneralSettings.showsDockIcon] }) { [weak self] _ in
            self?.applyActivationPolicy()
        }
    }

    /// Applies General ▸ Show in Dock.
    func applyActivationPolicy() {
        let policy = Self.activationPolicy(showsDockIcon: services.settings[GeneralSettings.showsDockIcon])
        guard NSApp.activationPolicy() != policy else { return }
        log.info("activation policy \(policy == .regular ? "regular" : "accessory", privacy: .public)")
        NSApp.setActivationPolicy(policy)
    }

    /// The Dock menu for the current state (the app delegate's `applicationDockMenu(_:)`).
    func menu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let boost = services.boost
        let commands = PanelCommands(services: services, source: .menu)
        for row in DockMenuRow.rows(for: boost.status) {
            switch row {
            case .separator: menu.addItem(.separator())
            case .master(let isOn): menu.addItem(ActionMenuItem.make(row.title) { boost.setOn(!isOn, source: .menu) })
            case .dimAll: menu.addItem(ActionMenuItem.make(row.title) { boost.toggleDim(source: .menu) })
            case .backToStandard: menu.addItem(ActionMenuItem.make(row.title) { boost.returnToStandard(source: .menu) })
            case .settings: menu.addItem(ActionMenuItem.make(row.title) { commands.openSettings(nil) })
            }
        }
        return menu
    }
}
