// OverbrightSettingsUI/Panes/ShortcutsPane.swift — Settings ▸ Shortcuts (DESIGN.md §7.6, D17): one recorder per global
// shortcut (WP0b's `ShortcutRow`: key caps in the live keyboard layout, conflict lines in place, clearing Back to
// Standard asks first), the step size of Brighter and Less Bright, and how to reach Overbright from the Shortcuts app
// and Control Center (the Run Shortcut recipe in builds without the dormant control). Seeded empty by WP0b behind the
// `SettingsPaneView` seam (ARCHITECTURE.md §10.2); WP11 owns it (§10.13).
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// Settings ▸ Shortcuts.
struct ShortcutsPane: SettingsPaneView {
    let services: OverbrightServices
    @State private var systemShortcuts = SystemShortcuts.knownDefaults

    /// The pane for `services`.
    init(services: OverbrightServices) { self.services = services }

    /// The shortcuts in DESIGN.md §7.6's order.
    static let order: [ShortcutID] = [.toggle, .brighter, .lessBright, .max, .dimToggle, .standard, .fillLight]

    /// The row of `id`'s recorder.
    static func row(_ id: ShortcutID) -> SettingsRowInfo {
        var keywords = [PaneWords.shortcut]
        switch id {
        case .brighter, .max: keywords.append(PaneWords.brighter)
        case .lessBright, .dimToggle: keywords.append(PaneWords.dim)
        default: break
        }
        return SettingsRowInfo(.shortcuts, "shortcut.\(id.rawValue)", title: id.localizedName() ?? id.rawValue,
                               keywords: keywords)
    }

    static var stepSize: SettingsRowInfo {
        SettingsRowInfo(.shortcuts, "stepSize",
                        title: String(localized: "Step size", bundle: .module,
                                      comment: "Settings ▸ Shortcuts: how much one press of Brighter or Less Bright changes (segmented)"),
                        keywords: [PaneWords.brighter, PaneWords.dim])
    }

    static var shortcutsApp: SettingsRowInfo {
        SettingsRowInfo(.shortcuts, "shortcutsApp",
                        title: String(localized: "Overbright’s actions are in the Shortcuts app: turn it on or off, set extra brightness, dim, pause, and more.",
                                      bundle: .module, comment: "Settings ▸ Shortcuts: note about the Shortcuts app; “Shortcuts” is macOS’s own app name"),
                        keywords: [PaneWords.controlCenter])
    }

    /// The searchable rows.
    static func rows(services: OverbrightServices) -> [SettingsRowInfo] {
        order.map(row) + [stepSize, shortcutsApp]
    }

    /// The rows with a value and their Reset to Default (a recorder's: the catalog default).
    static func values(services: OverbrightServices) -> [RowValue] {
        let settings = services.settings
        return order.map { id in
            RowValue(row(id), isDefault: { settings[ShortcutSettings.bindings][id] == nil }) {
                settings[ShortcutSettings.bindings][id] = nil
            }
        } + [RowValue(stepSize, settings: settings, key: ShortcutSettings.stepSize)]
    }

    /// Rows that show no value of their own.
    static let actionRows: Set<String> = [shortcutsApp.id]

    /// The footnote of a recorder (DESIGN.md §7.6), nil when it has none.
    static func footnote(_ id: ShortcutID) -> String? {
        switch id {
        case .lessBright:
            String(localized: "Stops at Standard first; press again to dim below it.", bundle: .module,
                   comment: "Settings ▸ Shortcuts: footnote of Less Bright")
        case .dimToggle:
            String(localized: "Dims every display to your last dim level, or brings them back.", bundle: .module,
                   comment: "Settings ▸ Shortcuts: footnote of Dim Below Minimum On or Off")
        case .standard:
            String(localized: "Turns Overbright off at once, from anywhere. Your levels are kept for next time.", bundle: .module,
                   comment: "Settings ▸ Shortcuts: footnote of Back to Standard")
        default:
            nil
        }
    }

    /// The step-size footnote, with "6 %" in the user's locale.
    static func stepSizeFootnote(locale: Locale = .autoupdatingCurrent) -> String {
        let fine = PaneFormat.percent(6, locale: locale)
        return String(localized: "Each press of Brighter or Less Bright changes the light by about a fifth (Regular) or about \(fine) (Fine).",
                      bundle: .module, comment: "Settings ▸ Shortcuts: footnote of Step size; the argument is a percentage such as 6%")
    }

    /// This build ships the Control Center control (the dormant extension of D18, `CONTROLS=1`).
    static var hasControl: Bool {
        guard let plugIns = Bundle.main.builtInPlugInsURL else { return false }
        return FileManager.default.fileExists(atPath: plugIns.appending(path: "OverbrightControls.appex").path)
    }

    var body: some View {
        let names = Dictionary(uniqueKeysWithValues: Self.order.map { ($0, $0.localizedName() ?? $0.rawValue) })
        SettingsForm(.shortcuts) {
            Section {
                ForEach(Self.order, id: \.self) { id in
                    if let shortcut = ShortcutCatalog.all.first(where: { $0.id == id }) {
                        ShortcutRow(info: Self.row(id), shortcut: shortcut, services: services, names: names,
                                    system: systemShortcuts, footnote: Self.footnote(id))
                    }
                }
            }
            Section {
                ChoiceRow(Self.stepSize, settings: services.settings, key: ShortcutSettings.stepSize,
                          choices: StepSize.allCases.map { Choice(value: $0, label: $0.localizedName()) },
                          footnote: Self.stepSizeFootnote(), style: .segmented)
            }
            Section {
                VStack(alignment: .leading, spacing: Space.m) {
                    HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                        Text(verbatim: Self.shortcutsApp.title)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: Space.m)
                        Button { SystemSettingsLink.open(SystemSettingsLink.shortcutsApp) } label: {
                            Text("Open Shortcuts", bundle: .module,
                                 comment: "Settings ▸ Shortcuts: opens the Shortcuts app (title case; “Shortcuts” is macOS’s own app name)")
                        }
                    }
                    if !Self.hasControl {
                        Text("To put Overbright in Control Center or the menu bar, make a shortcut with Turn Overbright On or Off, then add Control Center’s Run Shortcut control.",
                             bundle: .module,
                             comment: "Settings ▸ Shortcuts: the Run Shortcut recipe; “Turn Overbright On or Off” is the Shortcuts action’s title, “Run Shortcut” the Control Center control’s name")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .searchTarget(Self.shortcutsApp)
            } header: {
                Text("Shortcuts app and Control Center", bundle: .module,
                     comment: "Settings ▸ Shortcuts: section header; “Shortcuts” and “Control Center” are macOS’s own names")
            }
        }
        .task { systemShortcuts = await SystemShortcuts.load() }
    }
}

#Preview("Shortcuts") {
    ShortcutsPane(services: .preview())
        .environment(SettingsNavigator(target: "shortcuts"))
        .frame(width: 650, height: 700)
        .overbrightThemeRoot()
}
