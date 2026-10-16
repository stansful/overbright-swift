// OverbrightSettingsUI/Panes/AutomationsScheduleSection.swift — Automations ▸ Schedule (DESIGN.md §7.5): "Only allow
// extra brightness at set times" (off by default; on, it starts at 08:00–20:00) and, while it is on, the From and To
// time pickers in the user's 12- or 24-hour clock. Outside the hours Overbright stays at Standard; dimming still works.
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// The schedule's switch and its hours.
struct AutomationsScheduleSection: View {
    let services: OverbrightServices

    var body: some View {
        let settings = services.settings
        let schedule = settings[AutomationSettings.schedule]
        let isOn = Binding<Bool>(get: { settings[AutomationSettings.schedule] != nil }, set: { on in
            settings[AutomationSettings.schedule] = on ? ScheduleEditing.defaultWindow : nil
        })
        Section {
            Toggle(isOn: isOn) {
                RowLabel(title: AutomationsRows.schedule.title,
                         footnote: String(localized: "Outside these hours Overbright stays at Standard. Dimming still works.",
                                          bundle: .module, comment: "Settings ▸ Automations: footnote of the schedule switch"))
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .settingRow(AutomationsRows.schedule, settings: settings, key: AutomationSettings.schedule)
            if let schedule {
                let values = AutomationsPane.scheduleTimeValues(services)
                timeRow(values[0], minute: schedule.startMinute) { minute in
                    settings[AutomationSettings.schedule] = ScheduleEditing.setting(start: minute,
                                                                                    in: settings[AutomationSettings.schedule])
                }
                timeRow(values[1], minute: schedule.endMinute) { minute in
                    settings[AutomationSettings.schedule] = ScheduleEditing.setting(end: minute,
                                                                                    in: settings[AutomationSettings.schedule])
                }
            }
        } header: {
            Text("Schedule", bundle: .module, comment: "Settings ▸ Automations: section header")
        }
    }

    private func timeRow(_ value: RowValue, minute: Int, set: @escaping (Int) -> Void) -> some View {
        let date = Binding<Date>(get: { ScheduleEditing.date(minuteOfDay: minute) },
                                 set: { set(ScheduleEditing.minuteOfDay($0)) })
        return DatePicker(selection: date, displayedComponents: .hourAndMinute) {
            Text(verbatim: value.info.title)
        }
        .datePickerStyle(.stepperField)
        .settingRow(value)
    }
}

#Preview("Schedule") {
    let services = OverbrightServices.preview()
    services.settings[AutomationSettings.schedule] = ScheduleEditing.defaultWindow
    return Form { AutomationsScheduleSection(services: services) }
        .formStyle(.grouped)
        .environment(SettingsNavigator(target: "automations"))
        .frame(width: 600, height: 260)
}
