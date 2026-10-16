// OverbrightSettingsUI/Panes/AutomationsPane.swift — Settings ▸ Automations (DESIGN.md §7.5): power (on battery, the
// battery level, Low Power Mode, the live power line), the heat note, the timer, apps and video (full-screen video,
// every full-screen app, games, the per-app list), the schedule, the OLED idle pause (only when an OLED display is
// known) and the Focus note. The power and heat rules stop extra brightness only; dimming always works. Seeded empty
// by WP0b behind the `SettingsPaneView` seam (ARCHITECTURE.md §10.2); WP11 owns it (§10.13).
import OverbrightCore
import OverbrightDesign
import OverbrightPolicy
import SwiftUI

/// Settings ▸ Automations.
struct AutomationsPane: SettingsPaneView {
    let services: OverbrightServices

    /// The pane for `services`.
    init(services: OverbrightServices) { self.services = services }

    /// The searchable rows, as the pane shows them now.
    static func rows(services: OverbrightServices) -> [SettingsRowInfo] {
        var rows = [AutomationsRows.batteryGuard]
        if showsBatteryLevel(services) { rows.append(AutomationsRows.batteryThreshold) }
        rows += [AutomationsRows.lowPowerMode, AutomationsRows.powerNow, AutomationsRows.heat, AutomationsRows.timer,
                 AutomationsRows.fullScreenVideo, AutomationsRows.everyFullScreenApp, AutomationsRows.games,
                 AutomationsRows.pausedApps, AutomationsRows.schedule]
        if services.settings[AutomationSettings.schedule] != nil {
            rows += [AutomationsRows.scheduleFrom, AutomationsRows.scheduleTo]
        }
        if knowsOLED(services) { rows.append(AutomationsRows.oledIdle) }
        return rows + [AutomationsRows.focus]
    }

    /// The rows with a value and their Reset to Default.
    static func values(services: OverbrightServices) -> [RowValue] {
        let settings = services.settings
        var values = [RowValue(AutomationsRows.batteryGuard, settings: settings, key: AutomationSettings.batteryGuard)]
        if showsBatteryLevel(services) {
            values.append(RowValue(AutomationsRows.batteryThreshold, settings: settings, key: AutomationSettings.batteryThreshold))
        }
        values += [
            RowValue(AutomationsRows.lowPowerMode, settings: settings, key: AutomationSettings.pauseInLowPowerMode),
            RowValue(AutomationsRows.timer, settings: settings, key: AutomationSettings.autoOffMinutes),
            RowValue(AutomationsRows.fullScreenVideo, settings: settings, key: AutomationSettings.pauseForFullScreenVideo),
            RowValue(AutomationsRows.everyFullScreenApp, settings: settings, key: AutomationSettings.pauseForAllFullScreen),
            RowValue(AutomationsRows.games, settings: settings, key: AutomationSettings.pauseInGames),
            pausedAppsValue(services),
            RowValue(AutomationsRows.schedule, settings: settings, key: AutomationSettings.schedule),
        ]
        if settings[AutomationSettings.schedule] != nil {
            values += scheduleTimeValues(services)
        }
        if knowsOLED(services) {
            values.append(RowValue(AutomationsRows.oledIdle, settings: settings, key: AutomationSettings.oledIdleMinutes))
        }
        return values
    }

    /// Rows that show no value of their own (the live power line, the heat and Focus notes).
    static let actionRows: Set<String> = [AutomationsRows.powerNow.id, AutomationsRows.heat.id, AutomationsRows.focus.id]

    /// The battery level matters only while extra brightness pauses below one.
    static func showsBatteryLevel(_ services: OverbrightServices) -> Bool {
        services.settings[AutomationSettings.batteryGuard] == .belowThreshold
    }

    /// An OLED display is known: connected now (detected, or set by the user), or set to OLED while away.
    static func knowsOLED(_ services: OverbrightServices) -> Bool {
        let preferences = services.settings[DisplaySettings.perDisplay]
        let connected = services.displays.displays.contains { facts in
            EligibilityClassifier.isOLED(facts, override: preferences[facts.ref.key]?.oled ?? .automatic)
        }
        return connected || preferences.values.contains { $0.oled == .oled }
    }

    /// The switch and the list of Pause for these apps: Reset to Default restores both.
    static func pausedAppsValue(_ services: OverbrightServices) -> RowValue {
        let settings = services.settings
        return RowValue(AutomationsRows.pausedApps, isDefault: {
            settings.isDefault(AutomationSettings.pauseForListedApps) && settings.isDefault(AutomationSettings.pausedApps)
        }) {
            settings.reset(AutomationSettings.pauseForListedApps)
            settings.reset(AutomationSettings.pausedApps)
        }
    }

    /// From and To: each returns its own end of the window to 08:00 or 20:00.
    static func scheduleTimeValues(_ services: OverbrightServices) -> [RowValue] {
        let settings = services.settings
        return [
            RowValue(AutomationsRows.scheduleFrom, isDefault: {
                (settings[AutomationSettings.schedule]?.startMinute ?? ScheduleEditing.defaultStart) == ScheduleEditing.defaultStart
            }) {
                settings[AutomationSettings.schedule] = ScheduleEditing.setting(start: ScheduleEditing.defaultStart,
                                                                                in: settings[AutomationSettings.schedule])
            },
            RowValue(AutomationsRows.scheduleTo, isDefault: {
                (settings[AutomationSettings.schedule]?.endMinute ?? ScheduleEditing.defaultEnd) == ScheduleEditing.defaultEnd
            }) {
                settings[AutomationSettings.schedule] = ScheduleEditing.setting(end: ScheduleEditing.defaultEnd,
                                                                                in: settings[AutomationSettings.schedule])
            },
        ]
    }

    var body: some View {
        let settings = services.settings
        SettingsForm(.automations) {
            powerSection
            Section {
                LabeledContent {
                    EmptyView()
                } label: {
                    RowLabel(title: AutomationsRows.heat.title,
                             footnote: String(localized: "Overbright limits extra brightness when your Mac gets warm and turns it off when it gets hot. This can’t be turned off.",
                                              bundle: .module, comment: "Settings ▸ Automations: the heat note"))
                }
                .searchTarget(AutomationsRows.heat)
            }
            Section {
                ChoiceRow(AutomationsRows.timer, settings: settings, key: AutomationSettings.autoOffMinutes,
                          choices: PaneFormat.autoOffMinutes.map { Choice(value: $0, label: PaneFormat.autoOff($0)) },
                          footnote: String(localized: "Counts from when you turn Overbright on.", bundle: .module,
                                           comment: "Settings ▸ Automations: footnote of Turn off after"),
                          style: .menu)
            } header: {
                Text("Timer", bundle: .module, comment: "Settings ▸ Automations: section header")
            }
            appsSection
            AutomationsScheduleSection(services: services)
            if Self.knowsOLED(services) {
                Section {
                    ChoiceRow(AutomationsRows.oledIdle, settings: settings, key: AutomationSettings.oledIdleMinutes,
                              choices: PaneFormat.oledIdleMinutes.map { Choice(value: $0, label: PaneFormat.duration(minutes: $0)) },
                              footnote: String(localized: "Video that keeps your Mac awake doesn’t count as no input.", bundle: .module,
                                               comment: "Settings ▸ Automations: footnote of the OLED idle pause"),
                              style: .menu)
                } header: {
                    Text("OLED displays", bundle: .module, comment: "Settings ▸ Automations: section header")
                }
            }
            Section {
                HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                    Text(verbatim: AutomationsRows.focus.title)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: Space.m)
                    Button { SystemSettingsLink.open(SystemSettingsLink.focus) } label: {
                        Text(verbatim: SystemSettingsLink.openSystemSettings)
                    }
                }
                .searchTarget(AutomationsRows.focus)
            } header: {
                Text(verbatim: String(localized: "automations.section.focus", defaultValue: "Focus", bundle: .module,
                                      comment: "Settings ▸ Automations: section header; “Focus” is macOS’s own name"))
            }
        }
    }

    private var powerSection: some View {
        let settings = services.settings
        return Section {
            ChoiceRow(AutomationsRows.batteryGuard, settings: settings, key: AutomationSettings.batteryGuard,
                      choices: BatteryGuard.allCases.map { Choice(value: $0, label: $0.localizedName()) }, style: .menu)
            if Self.showsBatteryLevel(services) {
                ChoiceRow(AutomationsRows.batteryThreshold, settings: settings, key: AutomationSettings.batteryThreshold,
                          choices: PaneFormat.batteryThresholds.map { Choice(value: $0, label: PaneFormat.percent($0)) },
                          style: .menu)
            }
            ToggleRow(info: AutomationsRows.lowPowerMode, settings: settings, key: AutomationSettings.pauseInLowPowerMode)
            LabeledContent {
                Text(verbatim: PowerStateText.make(services.signals.snapshot.power))
                    .foregroundStyle(.secondary)
            } label: {
                Text(verbatim: AutomationsRows.powerNow.title)
            }
            .searchTarget(AutomationsRows.powerNow)
        } header: {
            Text("Power", bundle: .module, comment: "Settings ▸ Automations: section header")
        } footer: {
            Text("These limits stop extra brightness only. Dimming below the minimum always works, because it saves power.",
                 bundle: .module, comment: "Settings ▸ Automations: note under the power rows")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var appsSection: some View {
        let settings = services.settings
        return Section {
            ToggleRow(info: AutomationsRows.fullScreenVideo, settings: settings, key: AutomationSettings.pauseForFullScreenVideo,
                      footnote: String(localized: "Pauses while an app plays video full screen on that display, including browsers.",
                                       bundle: .module, comment: "Settings ▸ Automations: footnote of Pause for full-screen video"))
            ToggleRow(info: AutomationsRows.everyFullScreenApp, settings: settings, key: AutomationSettings.pauseForAllFullScreen,
                      footnote: String(localized: "Includes documents and games, not just video.", bundle: .module,
                                       comment: "Settings ▸ Automations: footnote of Pause for every full-screen app"))
            ToggleRow(info: AutomationsRows.games, settings: settings, key: AutomationSettings.pauseInGames,
                      footnote: String(localized: "Apps that macOS knows as games, while in front.", bundle: .module,
                                       comment: "Settings ▸ Automations: footnote of Pause in games"))
            PausedAppsEditor(services: services, value: Self.pausedAppsValue(services))
        } header: {
            Text("Apps and video", bundle: .module, comment: "Settings ▸ Automations: section header")
        }
    }
}

#Preview("Automations") {
    AutomationsPane(services: .preview(fixture: .mpg322uxHDROn))
        .environment(SettingsNavigator(target: "automations"))
        .frame(width: 650, height: 1100)
        .overbrightThemeRoot()
}
