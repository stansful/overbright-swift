// OverbrightSignals/Schedule/ScheduleTimer.swift — when the schedule window opens or closes. ARCHITECTURE.md §3.4
// (`ScheduleWindow`), §7.1 ("Schedule boundary": one `TimeSource.sleep` until the next boundary → re-reduce), D10, D22.
// The boundaries are the window's start and end minutes in local time (the calendar's time zone; `.nextTime` resolves a
// minute that a daylight-saving jump skips to the next existing time). The runner in `SignalsMonitor` sleeps towards the
// next boundary in chunks of at most 5 minutes, so a wall-clock or time-zone change, or a long system sleep, costs at
// most one chunk of delay, and judges "crossed" against the wall clock after every wake.
// Thread: any (pure).
import Foundation
import OverbrightCore

/// Pure schedule-boundary arithmetic.
nonisolated enum ScheduleTimer {
    /// Longest single sleep towards a boundary.
    static let maximumSleep: Duration = .seconds(300)
    /// Seconds past the boundary minute at which the event fires, so `minuteOfDay` already reads the new minute.
    static let margin: TimeInterval = 1

    /// The first start or end minute strictly after `now`, in `calendar`'s time zone.
    static func nextBoundary(after now: Date, window: ScheduleWindow, calendar: Calendar) -> Date? {
        Set([window.startMinute, window.endMinute]).compactMap { minute in
            calendar.nextDate(after: now, matching: DateComponents(hour: minute / 60, minute: minute % 60, second: 0),
                              matchingPolicy: .nextTime)
        }.min()
    }

    /// Whether a boundary lies in `(last, now]` (false when the clock went backwards).
    static func crossedBoundary(from last: Date, to now: Date, window: ScheduleWindow, calendar: Calendar) -> Bool {
        guard now > last, let boundary = nextBoundary(after: last, window: window, calendar: calendar) else { return false }
        return boundary.addingTimeInterval(margin) <= now
    }

    /// The next sleep: to the boundary plus the margin, at most `maximumSleep`, never negative.
    static func sleepDuration(until boundary: Date, now: Date) -> Duration {
        let seconds = min(max(boundary.timeIntervalSince(now) + margin, 0), maximumSleep.timeInterval)
        return .milliseconds(Int64((seconds * 1000).rounded(.up)))
    }
}
