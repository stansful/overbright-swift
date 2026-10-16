// OverbrightSignals/Schedule/ScheduleTimer.swift — when the schedule window opens or closes. ARCHITECTURE.md §3.4
// (`ScheduleWindow`), §7.1 ("Schedule boundary": one `TimeSource.sleep` until the next boundary → re-reduce), D10, D22.
// The boundaries are the window's start and end minutes in local time (the calendar's time zone; `.nextTime` resolves a
// minute that a daylight-saving jump skips to the next existing time). The runner in `SignalsMonitor` sleeps towards the
// next boundary plus a 1 s margin, in chunks of at most 5 minutes, so a wall-clock or time-zone change, or a long system
// sleep, costs at most one chunk of delay. After every wake it judges "crossed" against the boundary itself (not the
// boundary plus the margin: a wake that timer slack or an NTP slew lands inside the margin still counts), and also
// posts when the window's inside/outside state differs from the one recorded at the previous wake (a clock stepped
// back over a boundary, or a time-zone change that moved local time over one without crossing it in absolute time).
// Thread: any (pure).
import Foundation
import OverbrightCore

/// Pure schedule-boundary arithmetic.
nonisolated enum ScheduleTimer {
    /// Longest single sleep towards a boundary.
    static let maximumSleep: Duration = .seconds(300)
    /// Seconds past the boundary minute the runner sleeps to, so the wake normally lands on the new minute.
    static let margin: TimeInterval = 1

    /// The first start or end minute strictly after `now`, in `calendar`'s time zone.
    static func nextBoundary(after now: Date, window: ScheduleWindow, calendar: Calendar) -> Date? {
        Set([window.startMinute, window.endMinute]).compactMap { minute in
            calendar.nextDate(after: now, matching: DateComponents(hour: minute / 60, minute: minute % 60, second: 0),
                              matchingPolicy: .nextTime)
        }.min()
    }

    /// Whether a boundary lies in `(last, now]` (false when the clock went backwards). At `now` the boundary's minute
    /// has begun, so the engine's `minuteOfDay` already reads it.
    static func crossedBoundary(from last: Date, to now: Date, window: ScheduleWindow, calendar: Calendar) -> Bool {
        guard now > last, let boundary = nextBoundary(after: last, window: window, calendar: calendar) else { return false }
        return boundary <= now
    }

    /// Whether `date` lies inside `window` in `calendar`'s local time.
    static func isInside(_ date: Date, window: ScheduleWindow, calendar: Calendar) -> Bool {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return window.contains(minuteOfDay: (parts.hour ?? 0) * 60 + (parts.minute ?? 0))
    }

    /// Whether the runner posts after a wake at `now`: a boundary lies in `(last, now]`, or the window's inside state
    /// differs from `wasInside`, the state recorded at `last` (with the calendar of that moment).
    static func shouldPost(last: Date, wasInside: Bool, now: Date, window: ScheduleWindow, calendar: Calendar) -> Bool {
        crossedBoundary(from: last, to: now, window: window, calendar: calendar)
            || isInside(now, window: window, calendar: calendar) != wasInside
    }

    /// The next sleep: to the boundary plus the margin, at most `maximumSleep`, never negative.
    static func sleepDuration(until boundary: Date, now: Date) -> Duration {
        let seconds = min(max(boundary.timeIntervalSince(now) + margin, 0), maximumSleep.timeInterval)
        return .milliseconds(Int64((seconds * 1000).rounded(.up)))
    }
}
