// OverbrightSettingsUI/Root/SettingsPane.swift — what the sidebar, the search and the footer know about a pane:
// its name, its sidebar icon and the settings namespaces "Reset ‹Pane›…" resets. DESIGN.md §7.1, §7.2, §12.9.
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// One pane's sidebar entry.
struct SettingsPane: Identifiable, Equatable {
    /// The pane.
    let id: SettingsPaneID
    /// The sidebar title and window title, localized.
    let title: String
    /// The white glyph of the sidebar icon (DESIGN.md §7.1).
    let symbol: OverbrightSymbol
    /// The system colour behind the glyph.
    let tint: Tint
    /// Namespaces "Reset ‹Pane›…" resets; empty = the pane has no footer (About).
    let namespaces: [SettingsNamespace]

    /// The system colours of DESIGN.md §7.1.
    enum Tint: Equatable {
        case gray, blue, green, indigo, orange

        /// The system colour.
        var color: Color {
            switch self {
            case .gray: .gray
            case .blue: .blue
            case .green: .green
            case .indigo: .indigo
            case .orange: .orange
            }
        }
    }

    /// Every pane in sidebar order (DESIGN.md §7.1). General's footer also resets the update switches (its Updates
    /// section); records that share a namespace are kept (`PaneReset`).
    static var all: [SettingsPane] {
        [
            SettingsPane(id: .general, title: String(localized: "General", bundle: .module,
                                                     comment: "Settings: sidebar pane name and window title"),
                         symbol: .gearshapeFill, tint: .gray, namespaces: [.general, .updates]),
            SettingsPane(id: .displays, title: String(localized: "Displays", bundle: .module,
                                                      comment: "Settings: sidebar pane name and window title"),
                         symbol: .display, tint: .blue, namespaces: [.displays]),
            SettingsPane(id: .automations, title: String(localized: "Automations", bundle: .module,
                                                         comment: "Settings: sidebar pane name and window title"),
                         symbol: .boltFill, tint: .green, namespaces: [.automations]),
            SettingsPane(id: .shortcuts, title: String(localized: "Shortcuts", bundle: .module,
                                                       comment: "Settings: sidebar pane name and window title (keyboard shortcuts and the Shortcuts app)"),
                         symbol: .keyboard, tint: .indigo, namespaces: [.shortcuts]),
            SettingsPane(id: .fillLight, title: String(localized: "Fill Light", bundle: .module,
                                                       comment: "Settings: sidebar pane name and window title (the edge light, glossary: Fill Light)"),
                         symbol: .personCropRectangle, tint: .orange, namespaces: [.fillLight]),
            SettingsPane(id: .advanced, title: String(localized: "Advanced", bundle: .module,
                                                      comment: "Settings: sidebar pane name and window title"),
                         symbol: .wrenchAndScrewdriverFill, tint: .gray, namespaces: [.advanced]),
            SettingsPane(id: .about, title: String(localized: "About", bundle: .module,
                                                   comment: "Settings: sidebar pane name and window title"),
                         symbol: .infoCircleFill, tint: .gray, namespaces: []),
        ]
    }

    /// The entry of `id`.
    static func pane(_ id: SettingsPaneID) -> SettingsPane {
        all.first { $0.id == id } ?? SettingsPane(id: id, title: id.rawValue, symbol: .gearshapeFill, tint: .gray,
                                                   namespaces: [])
    }
}
