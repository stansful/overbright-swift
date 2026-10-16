// OverbrightSettingsUI/Panes/GeneralPane.swift — Settings ▸ General (DESIGN.md §7.3): the warning row while the menu bar
// icon cannot be seen, startup (when you log in, with the approval line), the menu bar (show the icon, which asks
// first before hiding it; what a click does; the Dock icon; Quit Overbright), feedback (the HUD, haptics) and the
// update check (WP0b's `UpdatesSection`, only when this build has a repository). Seeded by WP0b behind the
// `SettingsPaneView` seam (ARCHITECTURE.md §10.2); WP11 owns it (§10.13).
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// Settings ▸ General.
struct GeneralPane: SettingsPaneView {
    let services: OverbrightServices

    /// The pane for `services`.
    init(services: OverbrightServices) { self.services = services }

    /// The searchable rows (the warning row only while the icon cannot be seen).
    static func rows(services: OverbrightServices) -> [SettingsRowInfo] {
        var rows: [SettingsRowInfo] = []
        if services.app?.iconVisibility == .notVisible { rows.append(GeneralRows.iconWarning) }
        rows += [GeneralRows.launchBehavior, GeneralRows.menuBarIcon, GeneralRows.clickAction, GeneralRows.dockIcon,
                 GeneralRows.quit, GeneralRows.showsHUD, GeneralRows.haptics]
        return rows + UpdatesSection.rows(services: services)
    }

    /// The rows with a value and their Reset to Default (the login item and the icon follow through `AppControl`).
    static func values(services: OverbrightServices) -> [RowValue] {
        let settings = services.settings
        var values = [
            launchBehaviorValue(services: services),
            menuBarIconValue(services: services),
            RowValue(GeneralRows.clickAction, settings: settings, key: GeneralSettings.clickAction),
            RowValue(GeneralRows.dockIcon, settings: settings, key: GeneralSettings.showsDockIcon),
            RowValue(GeneralRows.showsHUD, settings: settings, key: GeneralSettings.showsHUD),
            RowValue(GeneralRows.haptics, settings: settings, key: GeneralSettings.haptics),
        ]
        if services.updates.isConfigured {
            values += [RowValue(UpdatesSection.automatic, settings: settings, key: UpdateSettings.automatic),
                       RowValue(UpdatesSection.prereleases, settings: settings, key: UpdateSettings.prereleases)]
        }
        return values
    }

    /// When you log in: its reset goes through the app, so the login item follows.
    static func launchBehaviorValue(services: OverbrightServices) -> RowValue {
        RowValue(GeneralRows.launchBehavior, isDefault: { services.settings.isDefault(GeneralSettings.launchBehavior) }) {
            setLaunchBehavior(GeneralSettings.launchBehavior.defaultValue, services: services)
        }
    }

    /// Show menu bar icon: its reset goes through the app, so the icon comes back.
    static func menuBarIconValue(services: OverbrightServices) -> RowValue {
        RowValue(GeneralRows.menuBarIcon, isDefault: { services.settings.isDefault(GeneralSettings.showsMenuBarIcon) }) {
            setMenuBarIconVisible(GeneralSettings.showsMenuBarIcon.defaultValue, services: services)
        }
    }

    /// Rows that show no value of their own (an action or a state of the system).
    static let actionRows: Set<String> = [GeneralRows.iconWarning.id, GeneralRows.quit.id, UpdatesSection.checkNow.id]

    /// Stores the launch behaviour through the app (which keeps the login item in step), or in the store alone.
    static func setLaunchBehavior(_ behavior: LaunchBehavior, services: OverbrightServices) {
        if let app = services.app { app.setLaunchBehavior(behavior) } else { services.settings[GeneralSettings.launchBehavior] = behavior }
    }

    /// Shows or hides the menu bar icon through the app (which installs or removes it), or in the store alone.
    static func setMenuBarIconVisible(_ visible: Bool, services: OverbrightServices) {
        if let app = services.app { app.setMenuBarIconVisible(visible) } else { services.settings[GeneralSettings.showsMenuBarIcon] = visible }
    }

    var body: some View {
        SettingsForm(.general) {
            if services.app?.iconVisibility == .notVisible {
                Section {
                    IconWarningRow(toggleKeys: services.shortcuts.displayString(.toggle))
                }
            }
            Section {
                LaunchBehaviorRow(services: services)
                    .settingRow(Self.launchBehaviorValue(services: services))
            } header: {
                Text("Startup", bundle: .module, comment: "Settings ▸ General: section header")
            }
            Section {
                MenuBarIconRow(services: services)
                    .settingRow(Self.menuBarIconValue(services: services))
                ChoiceRow(GeneralRows.clickAction, settings: services.settings, key: GeneralSettings.clickAction,
                          choices: StatusClickAction.allCases.map { Choice(value: $0, label: $0.localizedName()) },
                          footnote: String(localized: "Right-click or Control-click the icon for the menu.", bundle: .module,
                                           comment: "Settings ▸ General: footnote of Clicking the icon"),
                          style: .segmented)
                ToggleRow(info: GeneralRows.dockIcon, settings: services.settings, key: GeneralSettings.showsDockIcon,
                          footnote: String(localized: "Adds a Dock icon with a menu.", bundle: .module,
                                           comment: "Settings ▸ General: footnote of Show in Dock"))
                QuitRow(services: services)
            } header: {
                Text("Menu bar", bundle: .module, comment: "Settings ▸ General: section header (the menu bar icon and quitting)")
            }
            Section {
                ToggleRow(info: GeneralRows.showsHUD, settings: services.settings, key: GeneralSettings.showsHUD,
                          footnote: String(localized: "When you use a shortcut, the Shortcuts app or a Focus, and when Overbright pauses or resumes on its own.",
                                           bundle: .module, comment: "Settings ▸ General: footnote of Show level changes on screen"))
                ToggleRow(info: GeneralRows.haptics, settings: services.settings, key: GeneralSettings.haptics,
                          footnote: String(localized: "On a Force Touch trackpad, at Standard and at each preset.", bundle: .module,
                                           comment: "Settings ▸ General: footnote of Haptic feedback"))
            } header: {
                Text("Feedback", bundle: .module, comment: "Settings ▸ General: section header")
            }
            UpdatesSection(services: services)
        }
    }
}

/// Quit Overbright: a push button with its footnote (DESIGN.md §4.4, §7.3).
private struct QuitRow: View {
    let services: OverbrightServices

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Button { services.app?.quit() } label: { Text(verbatim: GeneralRows.quit.title) }
            Text("Your displays return to Standard. Open Overbright again from Finder or Spotlight.", bundle: .module,
                 comment: "Settings ▸ General: footnote of Quit Overbright")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .searchTarget(GeneralRows.quit)
    }
}

#Preview("General") {
    GeneralPane(services: .preview())
        .environment(SettingsNavigator(target: "general"))
        .frame(width: 650, height: 700)
        .overbrightThemeRoot()
}

#Preview("General · icon not visible") {
    let services = OverbrightServices.preview()
    (services.app as? PreviewAppControl)?.iconVisibility = .notVisible
    return GeneralPane(services: services)
        .environment(SettingsNavigator(target: "general"))
        .frame(width: 650, height: 800)
        .overbrightThemeRoot()
}
