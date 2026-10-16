// OverbrightAppShell/StatusItem/StatusMenuModel.swift — the rows of the right-click / ⌃-click menu as data, built
// fresh each time the menu opens. DESIGN.md §4.3 (rows, order and exact English, live key equivalents, per-display
// quick levels with the shown presets, "All Displays ▸" while linked, the pause line + Resume, Update Available),
// §4.2 (toggle mode puts Show Panel first), §12.3 (the banner's sentence and action as the first two lines).
// Menus cannot be rendered; `dump()` is what tests and `--qa-menu` read.
import Foundation
import OverbrightCore
import OverbrightDesign
import OverbrightPanelUI

/// One row of the status menu.
enum StatusMenuRow: Equatable {
    /// The banner's sentence, disabled.
    case status(String)
    /// The banner's action.
    case bannerAction(BannerAction)
    /// Show Panel (toggle mode).
    case showPanel
    /// A separator.
    case separator
    /// Turn On / Turn Off Overbright with the live toggle shortcut.
    case master(isOn: Bool, key: MenuKeyEquivalent?)
    /// Dim All Displays / Stop Dimming with the live Dim shortcut.
    case dimAll(isDimmed: Bool, key: MenuKeyEquivalent?)
    /// A display's submenu of quick levels.
    case display(DisplayKey, title: String, items: [CardMenuItem])
    /// The quick levels of every display while levels are linked (built on `model`'s display).
    case allDisplays(model: DisplayKey, items: [CardMenuItem])
    /// Pause for 1 Hour.
    case pause
    /// Paused Until ‹time›, disabled.
    case pausedUntil(Date)
    /// Resume.
    case resume
    /// Fill Light, checked while on.
    case fillLight(isOn: Bool)
    /// Update Available: Overbright ‹version›…
    case updateAvailable(version: String, url: URL)
    /// Settings… ⌘,
    case settings
    /// Help
    case help
    /// Quit Overbright ⌘Q
    case quit
}

/// The status menu's rows and the card models its display rows act on.
struct StatusMenuModel {
    /// The rows in order.
    let rows: [StatusMenuRow]
    /// The card model of every display row.
    let cards: [DisplayKey: DisplayCardModel]

    /// The menu for the state of `services` now.
    static func make(services: OverbrightServices) -> StatusMenuModel {
        let status = services.boost.status
        let settings = services.settings
        var rows: [StatusMenuRow] = []
        if let banner = status.banner {
            rows.append(.status(BannerModel.make(banner).sentence))
            if let action = BannerAction.primary(for: banner) { rows.append(.bannerAction(action)) }
        }
        if settings[GeneralSettings.clickAction] == .toggle { rows.append(.showPanel) }
        if !rows.isEmpty { rows.append(.separator) }
        rows.append(.master(isOn: status.isOn, key: MenuKeyEquivalent.of(.toggle, in: services.shortcuts)))
        rows.append(.dimAll(isDimmed: DimState.isEveryDisplayDimmed(status),
                            key: MenuKeyEquivalent.of(.dimToggle, in: services.shortcuts)))

        let shown = status.displays.filter { !PanelContent.isNonCapable($0) }
        let titles = CardTitles.titles(for: status.displays)
        var cards: [DisplayKey: DisplayCardModel] = [:]
        for display in shown { cards[display.key] = DisplayCardModel(status: display, isMasterOn: status.isOn, services: services) }
        let lastDimLight = settings[DisplaySettings.lastDimLight]
        if !shown.isEmpty { rows.append(.separator) }
        if settings[DisplaySettings.linkLevels], let first = shown.first, let model = cards[first.key] {
            rows.append(.allDisplays(model: first.key,
                                     items: CardMenu.items(for: model, lastDimLight: lastDimLight, contextMenu: false)))
        } else {
            for display in shown {
                guard let model = cards[display.key] else { continue }
                rows.append(.display(display.key, title: titles[display.key] ?? display.name,
                                     items: CardMenu.items(for: model, lastDimLight: lastDimLight, contextMenu: false)))
            }
        }

        rows.append(.separator)
        if let until = status.pausedUntil {
            rows += [.pausedUntil(until), .resume]
        } else {
            rows.append(.pause)
        }
        rows.append(.fillLight(isOn: services.fillLight.isOn))
        rows.append(.separator)
        if services.updates.isConfigured, case let .available(version, url) = services.updates.state {
            rows.append(.updateAvailable(version: version, url: url))
        }
        rows += [.settings, .help, .quit]
        return StatusMenuModel(rows: rows, cards: cards)
    }

    /// The rows as text, one line per row and submenu row ("✓" for checks, "(disabled)", key equivalents).
    func dump() -> [String] {
        rows.flatMap { row -> [String] in
            switch row {
            case .display(let key, let title, let items):
                return ["\(title) ▸"] + submenuLines(items, key: key)
            case .allDisplays(let key, let items):
                return ["\(StatusMenuText.allDisplays) ▸"] + submenuLines(items, key: key)
            default:
                return [StatusMenuRender.title(of: row) + StatusMenuRender.suffix(of: row)]
            }
        }
    }

    private func submenuLines(_ items: [CardMenuItem], key: DisplayKey) -> [String] {
        guard let model = cards[key] else { return [] }
        return items.map { item in
            guard let title = CardMenu.title(of: item, card: model) else { return "  ---" }
            let check = CardMenu.isChecked(item) ? "✓ " : ""
            return "  " + check + title + (item == .noExtraBrightness ? " (disabled)" : "")
        }
    }
}
