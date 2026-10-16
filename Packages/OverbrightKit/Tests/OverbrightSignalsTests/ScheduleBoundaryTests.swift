// OverbrightSignalsTests/ScheduleBoundaryTests.swift — the schedule's start and end minutes in local time, across
// midnight and daylight-saving jumps, and the event at the boundary. ARCHITECTURE.md §3.4, §7.1, D10.
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightSignals

@Suite struct ScheduleBoundaryTests {
    private func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier) ?? .gmt
        return calendar
    }

    private func date(_ calendar: Calendar, _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int,
                      _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))
            ?? .distantPast
    }

    private let daytime = ScheduleWindow(startMinute: 8 * 60, endMinute: 20 * 60)       // 08:00–20:00
    private let overnight = ScheduleWindow(startMinute: 22 * 60, endMinute: 6 * 60)      // 22:00–06:00

    @Test func theNextBoundaryIsTheNearerOfStartAndEnd() {
        let utc = calendar("UTC")
        #expect(ScheduleTimer.nextBoundary(after: date(utc, 2026, 5, 8, 7, 0), window: daytime, calendar: utc)
                == date(utc, 2026, 5, 8, 8, 0))
        #expect(ScheduleTimer.nextBoundary(after: date(utc, 2026, 5, 8, 12, 0), window: daytime, calendar: utc)
                == date(utc, 2026, 5, 8, 20, 0))
        #expect(ScheduleTimer.nextBoundary(after: date(utc, 2026, 5, 8, 21, 0), window: daytime, calendar: utc)
                == date(utc, 2026, 5, 9, 8, 0))
        // Exactly at a boundary: the next one (this one has been handled).
        #expect(ScheduleTimer.nextBoundary(after: date(utc, 2026, 5, 8, 8, 0), window: daytime, calendar: utc)
                == date(utc, 2026, 5, 8, 20, 0))
    }

    @Test func aWindowAcrossMidnight() {
        let utc = calendar("UTC")
        #expect(ScheduleTimer.nextBoundary(after: date(utc, 2026, 5, 8, 23, 30), window: overnight, calendar: utc)
                == date(utc, 2026, 5, 9, 6, 0))
        #expect(ScheduleTimer.nextBoundary(after: date(utc, 2026, 5, 9, 6, 30), window: overnight, calendar: utc)
                == date(utc, 2026, 5, 9, 22, 0))
    }

    @Test func boundariesFollowTheLocalTimeZone() {
        let moscow = calendar("Europe/Moscow")                                           // UTC+3
        let boundary = ScheduleTimer.nextBoundary(after: date(moscow, 2026, 5, 8, 7, 0), window: daytime, calendar: moscow)
        #expect(boundary == date(calendar("UTC"), 2026, 5, 8, 5, 0))
    }

    @Test func aMinuteThatDaylightSavingSkipsMovesToTheNextExistingTime() {
        let berlin = calendar("Europe/Berlin")                                           // 2026-03-29 02:00 → 03:00
        let window = ScheduleWindow(startMinute: 2 * 60 + 30, endMinute: 20 * 60)
        let boundary = ScheduleTimer.nextBoundary(after: date(berlin, 2026, 3, 29, 1, 0), window: window, calendar: berlin)
        let utc = calendar("UTC")
        #expect(boundary == date(utc, 2026, 3, 29, 1, 0))                               // 03:00 CEST, never skipped
        // The autumn repeat (03:00 → 02:00 on 2026-10-25): the first 02:30 is the boundary, the day still advances.
        let autumn = ScheduleTimer.nextBoundary(after: date(berlin, 2026, 10, 25, 1, 0), window: window, calendar: berlin)
        #expect(autumn == date(utc, 2026, 10, 25, 0, 30))
    }

    @Test func crossingIsJudgedAgainstTheWallClock() {
        let utc = calendar("UTC")
        let before = date(utc, 2026, 5, 8, 7, 59, 30)
        func crossed(to now: Date) -> Bool {
            ScheduleTimer.crossedBoundary(from: before, to: now, window: daytime, calendar: utc)
        }
        #expect(crossed(to: date(utc, 2026, 5, 8, 8, 0, 1)))
        // The boundary itself counts, and so does a wake inside the 1 s margin (timer slack, an NTP slew).
        #expect(crossed(to: date(utc, 2026, 5, 8, 8, 0, 0)))
        #expect(crossed(to: date(utc, 2026, 5, 8, 8, 0, 0).addingTimeInterval(0.5)))
        #expect(!crossed(to: date(utc, 2026, 5, 8, 7, 59, 59)))
        #expect(!ScheduleTimer.crossedBoundary(from: date(utc, 2026, 5, 8, 8, 0, 1), to: date(utc, 2026, 5, 8, 9, 0),
                                               window: daytime, calendar: utc))
        // The clock jumped forward over a boundary (a long sleep, the user set the time): crossed.
        #expect(ScheduleTimer.crossedBoundary(from: before, to: date(utc, 2026, 5, 8, 23, 0), window: daytime, calendar: utc))
        // The clock went backwards: nothing crossed.
        #expect(!ScheduleTimer.crossedBoundary(from: before, to: date(utc, 2026, 5, 8, 6, 0), window: daytime, calendar: utc))
    }

    @Test func aTimeZoneChangeOverABoundaryPostsWithoutACrossing() {
        // 07:30 in UTC (outside 08:00–20:00) becomes 09:30 when the Mac moves to UTC+2: no boundary lies in (last, now]
        // in the new zone, but the window's state changed.
        let utc = calendar("UTC")
        let johannesburg = calendar("Africa/Johannesburg")                               // UTC+2, no daylight saving
        let last = date(utc, 2026, 5, 8, 7, 30)
        let wasInside = ScheduleTimer.isInside(last, window: daytime, calendar: utc)
        let now = last.addingTimeInterval(300)
        #expect(!wasInside && ScheduleTimer.isInside(now, window: daytime, calendar: johannesburg))
        #expect(!ScheduleTimer.crossedBoundary(from: last, to: now, window: daytime, calendar: johannesburg))
        #expect(ScheduleTimer.shouldPost(last: last, wasInside: wasInside, now: now, window: daytime, calendar: johannesburg))
        // Nothing changed: no post.
        #expect(!ScheduleTimer.shouldPost(last: last, wasInside: wasInside, now: now, window: daytime, calendar: utc))
        // The clock stepped back over the start: inside before, outside now, no crossing forwards.
        let inside = date(utc, 2026, 5, 8, 8, 2)
        #expect(ScheduleTimer.shouldPost(last: inside, wasInside: true, now: date(utc, 2026, 5, 8, 7, 58),
                                         window: daytime, calendar: utc))
    }

    @Test func sleepsAreCappedSoClockChangesAreNoticed() {
        let now = Date(timeIntervalSinceReferenceDate: 0)
        #expect(ScheduleTimer.sleepDuration(until: now.addingTimeInterval(3600), now: now) == .seconds(300))
        #expect(ScheduleTimer.sleepDuration(until: now.addingTimeInterval(10), now: now) == .seconds(11))
        #expect(ScheduleTimer.sleepDuration(until: now.addingTimeInterval(-50), now: now) == .zero)
    }

    // MARK: In the monitor

    /// The manual clock's minute of day and second, in the harness calendar.
    @MainActor private func clock(_ harness: SignalsHarness) -> (minute: Int, second: Int) {
        let now = harness.time.wallClock
        let parts = harness.calendar.dateComponents([.hour, .minute, .second], from: now)
        return ((parts.hour ?? 0) * 60 + (parts.minute ?? 0), parts.second ?? 0)
    }

    @MainActor @Test func theMonitorPostsAtTheBoundaryWhileBoosting() async {
        let harness = SignalsHarness()
        let (minute, second) = clock(harness)
        let window = ScheduleWindow(startMinute: (minute + 600) % 1440, endMinute: (minute + 2) % 1440)
        let untilEnd = 120 - second                                          // seconds to the end minute
        harness.settings[AutomationSettings.schedule] = window
        await harness.start()
        var boundaries = 0
        let token = harness.monitor.addEventObserver { if $0 == .scheduleBoundary { boundaries += 1 } }
        harness.monitor.setBoostActive(true)
        #expect(harness.monitor.activeSources.contains(.scheduleBoundary))
        await harness.advance(.seconds(untilEnd - 1))
        #expect(boundaries == 0)
        await harness.advance(.seconds(2))                                  // the end minute plus the 1 s margin
        #expect(boundaries == 1)
        await harness.advance(.seconds(3600))                               // the next boundary is hours away
        #expect(boundaries == 1)
        token.cancel()
    }

    @MainActor @Test func aWakeInsideTheMarginStillPostsAndTheBoundaryIsNotSkipped() async {
        // The runner sleeps to the boundary plus 1 s; an NTP slew of −0.6 s during that sleep lands the wake 0.4 s past
        // the boundary. It must post now, and it must not jump to the boundary after.
        let harness = SignalsHarness()
        let (minute, second) = clock(harness)
        let window = ScheduleWindow(startMinute: (minute + 4) % 1440, endMinute: (minute + 2) % 1440)
        let untilEnd = 120 - second
        harness.settings[AutomationSettings.schedule] = window
        await harness.start()
        var boundaries = 0
        let token = harness.monitor.addEventObserver { if $0 == .scheduleBoundary { boundaries += 1 } }
        harness.monitor.setBoostActive(true)
        await harness.settle()                                               // the runner sleeps until end + 1 s
        harness.time.setWallClock(harness.time.wallClock.addingTimeInterval(-0.6))
        await harness.advance(.seconds(untilEnd + 1))
        #expect(boundaries == 1)                                             // woke at end + 0.4 s
        await harness.advance(.seconds(121))                                 // the start, two minutes later
        #expect(boundaries == 2)
        token.cancel()
    }

    @MainActor @Test func aClockSetForwardOverABoundaryPostsOnTheNextWake() async {
        let harness = SignalsHarness()
        let (minute, _) = clock(harness)
        harness.settings[AutomationSettings.schedule] = ScheduleWindow(startMinute: (minute + 47) % 1440,
                                                                        endMinute: (minute + 77) % 1440)
        await harness.start()
        var boundaries = 0
        let token = harness.monitor.addEventObserver { if $0 == .scheduleBoundary { boundaries += 1 } }
        harness.monitor.setBoostActive(true)
        await harness.settle()                                               // the loop sleeps (capped at 5 minutes)
        harness.time.setWallClock(harness.time.wallClock.addingTimeInterval(3600))   // the user sets the clock ahead
        await harness.advance(.seconds(300))                                // the capped sleep ends
        #expect(boundaries == 1)
        token.cancel()
    }

    @MainActor @Test func noScheduleOrNoBoostMeansNoTimer() async {
        let harness = SignalsHarness()
        await harness.start()
        harness.monitor.setBoostActive(true)
        #expect(!harness.monitor.activeSources.contains(.scheduleBoundary))
        harness.settings[AutomationSettings.schedule] = ScheduleWindow(startMinute: 0, endMinute: 60)
        await harness.settle()
        #expect(harness.monitor.activeSources.contains(.scheduleBoundary))
        harness.monitor.setBoostActive(false)
        #expect(!harness.monitor.activeSources.contains(.scheduleBoundary))
    }
}

