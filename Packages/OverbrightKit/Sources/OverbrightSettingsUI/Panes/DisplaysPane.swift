// OverbrightSettingsUI/Panes/DisplaysPane.swift — Settings ▸ Displays (DESIGN.md §7.4): all displays (the same level on
// all displays; extra brightness only near full brightness; external displays in the panel, only on a Mac with a
// built-in display), then one section per connected display (verdict and fix,
// extra brightness, level, limit, method, calibration, type; `DisplaySection`), then the displays that are not
// connected, with their last name and Forget. Seeded empty by WP0b behind the `SettingsPaneView` seam
// (ARCHITECTURE.md §10.2); WP11 owns it (§10.13).
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// Settings ▸ Displays.
struct DisplaysPane: SettingsPaneView {
    let services: OverbrightServices

    /// The pane for `services`.
    init(services: OverbrightServices) { self.services = services }

    /// One section model per connected display, built-in first (the directory's order), with the engine's status of
    /// it (an idle one while the engine has not published it yet).
    static func models(services: OverbrightServices) -> [DisplaySectionModel] {
        let settings = services.settings, boost = services.boost.status
        let editor = DisplayPreferencesEditor(settings: settings)
        return services.displays.displays.map { facts in
            let key = facts.ref.key
            let status = boost.displays.first { $0.key == key }
                ?? DisplayStatus(key: key, name: facts.name, phase: .idle, decision: nil, appliedGain: 1, appliedFactor: 1,
                                 strategy: nil, lastReading: nil, sdrWhite: nil)
            return DisplaySectionModel(status: status, facts: facts, preferences: editor.preferences(of: key),
                                       isMasterOn: boost.isOn, isPaused: boost.pausedUntil != nil,
                                       linkLevels: settings[DisplaySettings.linkLevels],
                                       linkedLevel: settings[DisplaySettings.linkedLevel],
                                       taper: settings[DisplaySettings.boostOnlyNearFullBrightness],
                                       machine: services.machine)
        }
    }

    /// The searchable rows: all displays, every connected display's rows, every remembered display.
    static func rows(services: OverbrightServices) -> [SettingsRowInfo] {
        var rows = [DisplaysRows.linkLevels, DisplaysRows.nearFullBrightness]
        if services.hasBuiltInDisplay { rows.append(DisplaysRows.externalDisplays) }
        return rows + models(services: services).flatMap(DisplaySection.rows)
            + remembered(services: services).map { DisplaysRows.remembered($0.key, name: $0.name) }
    }

    /// The rows with a value and their Reset to Default.
    static func values(services: OverbrightServices) -> [RowValue] {
        var values = [RowValue(DisplaysRows.linkLevels, settings: services.settings, key: DisplaySettings.linkLevels),
                      RowValue(DisplaysRows.nearFullBrightness, settings: services.settings,
                               key: DisplaySettings.boostOnlyNearFullBrightness)]
        if services.hasBuiltInDisplay {
            values.append(RowValue(DisplaysRows.externalDisplays, settings: services.settings,
                                   key: DisplaySettings.showsExternalDisplaysInPanel))
        }
        return values + models(services: services).flatMap { DisplaySection.values($0, services: services) }
    }

    /// Rows that show no value of their own: a display's verdict and advisory, a remembered display.
    static func actionRows(services: OverbrightServices) -> Set<String> {
        let models = models(services: services)
        return Set(models.map { DisplaysRows.section($0.key, name: $0.name).id }
                   + models.map { DisplaysRows.autoBrightness($0.key, name: $0.name).id }
                   + remembered(services: services).map { DisplaysRows.remembered($0.key, name: $0.name).id })
    }

    /// Displays with stored preferences that are not connected, with the name to show.
    static func remembered(services: OverbrightServices) -> [(key: DisplayKey, name: String)] {
        DisplayPreferencesEditor(settings: services.settings)
            .remembered(online: services.displays.displays.map(\.ref.key))
            .map { (key: $0.key, name: $0.preferences.lastKnownName ?? DisplaysRows.unnamedDisplay) }
    }

    var body: some View {
        let settings = services.settings
        SettingsForm(.displays) {
            Section {
                ToggleRow(info: DisplaysRows.linkLevels, settings: settings, key: DisplaySettings.linkLevels,
                          footnote: String(localized: "Moving one slider moves the others. Each display still stops at its own limit.",
                                           bundle: .module, comment: "Settings ▸ Displays: footnote of Same level on all displays"))
                ToggleRow(info: DisplaysRows.nearFullBrightness, settings: settings,
                          key: DisplaySettings.boostOnlyNearFullBrightness,
                          footnote: String(localized: "Extra brightness fades out as you lower the display brightness, so the brightness keys keep their normal range. Turn this off to multiply any brightness.",
                                           bundle: .module,
                                           comment: "Settings ▸ Displays: footnote of Add extra brightness only near full brightness"))
                if services.hasBuiltInDisplay {
                    ToggleRow(info: DisplaysRows.externalDisplays, settings: settings,
                              key: DisplaySettings.showsExternalDisplaysInPanel,
                              footnote: String(localized: "When it’s off, the panel shows only the built-in display. External displays keep their levels; adjust them below or in the menu.",
                                               bundle: .module,
                                               comment: "Settings ▸ Displays: footnote of Show external displays in the panel"))
                }
            } header: {
                Text("All displays", bundle: .module, comment: "Settings ▸ Displays: section header of the rows that apply to every display")
            }
            ForEach(Self.models(services: services), id: \.key) { model in
                DisplaySection(services: services, model: model)
            }
            let remembered = Self.remembered(services: services)
            if !remembered.isEmpty {
                Section {
                    ForEach(remembered, id: \.key) { display in
                        HStack(spacing: Space.m) {
                            Text(verbatim: display.name)
                            Spacer(minLength: Space.m)
                            Button {
                                DisplayPreferencesEditor(settings: settings).forget(display.key)
                            } label: {
                                Text("Forget", bundle: .module,
                                     comment: "Settings ▸ Displays: removes what Overbright remembers about a display that is not connected (title case)")
                            }
                        }
                        .searchTarget(DisplaysRows.remembered(display.key, name: display.name))
                    }
                } header: {
                    Text("Not connected", bundle: .module,
                         comment: "Settings ▸ Displays: section header of the displays Overbright remembers that are not connected now")
                }
            }
        }
    }
}

#Preview("Displays · built-in") {
    DisplaysPane(services: .preview())
        .environment(SettingsNavigator(target: "displays"))
        .frame(width: 650, height: 900)
        .overbrightThemeRoot()
}

#Preview("Displays · OLED external") {
    DisplaysPane(services: .preview(fixture: .mpg322uxHDROn))
        .environment(SettingsNavigator(target: "displays"))
        .frame(width: 650, height: 900)
        .overbrightThemeRoot()
}
