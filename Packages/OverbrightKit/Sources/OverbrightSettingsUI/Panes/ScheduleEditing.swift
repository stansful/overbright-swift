// OverbrightSettingsUI/Panes/ScheduleEditing.swift — Automations ▸ Schedule (DESIGN.md §7.5; ARCHITECTURE.md §3.4
// `ScheduleWindow`): the switch turns the window on at 08:00–20:00, the From and To pickers edit its minutes of the
// day (an end before the start spans midnight), and each picker's Reset to Default returns its own end. Time pickers
// show a `Date`; a minute of the day maps onto a fixed reference day in the calendar's time zone, so daylight saving
// never moves it. Pure (tested).
import Foundation
import OverbrightCore

/// The schedule's edits.
enum ScheduleEditing {
    /// 08:00, the start a new schedule gets.
    static let defaultStart = 8 * 60
    /// 20:00, the end a new schedule gets.
    static let defaultEnd = 20 * 60

    /// The window the switch turns on.
    static var defaultWindow: ScheduleWindow { ScheduleWindow(startMinute: defaultStart, endMinute: defaultEnd) }

    /// `schedule` with its start (or end) at `minute`; nil stays nil (the pickers show only while it is on).
    static func setting(start minute: Int, in schedule: ScheduleWindow?) -> ScheduleWindow? {
        schedule.map { ScheduleWindow(startMinute: minute, endMinute: $0.endMinute) }
    }

    /// `schedule` with its end at `minute`.
    static func setting(end minute: Int, in schedule: ScheduleWindow?) -> ScheduleWindow? {
        schedule.map { ScheduleWindow(startMinute: $0.startMinute, endMinute: minute) }
    }

    /// The time a picker shows for `minute` of the day.
    static func date(minuteOfDay minute: Int, calendar: Calendar = .autoupdatingCurrent) -> Date {
        let day = calendar.startOfDay(for: referenceDay)
        return calendar.date(byAdding: .minute, value: min(max(minute, 0), 1439), to: day) ?? day
    }

    /// The minute of the day a picker's `date` stands for.
    static func minuteOfDay(_ date: Date, calendar: Calendar = .autoupdatingCurrent) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return min(max((parts.hour ?? 0) * 60 + (parts.minute ?? 0), 0), 1439)
    }

    /// A day without a daylight-saving change in either hemisphere (1 January 2001, noon UTC).
    private static let referenceDay = Date(timeIntervalSinceReferenceDate: 12 * 3600)
}
