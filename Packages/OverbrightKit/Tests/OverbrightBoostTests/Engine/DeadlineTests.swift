// OverbrightBoostTests/Engine/DeadlineTests.swift — the engine's wall-clock deadlines (ARCHITECTURE.md §4.9, §7.1): the
// schedule boundary in local calendar time across daylight-saving days (C-BOOST-10), and the pause, the auto-off and
// the boundary slept in chunks of at most 5 min against the wall clock, so neither a timer's tolerance nor a clock
// change stretches them (C-BOOST-11).
import Foundation
import OverbrightCore
import OverbrightPolicy
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct DeadlineTests {
    private static func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier) ?? .gmt
        return calendar
    }

    private let berlin = Self.calendar("Europe/Berlin")

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        berlin.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    /// The boundaries after `start`, one after another.
    private func boundaries(_ window: ScheduleWindow, from start: Date, count: Int) -> [Date] {
        var now = start, found: [Date] = []
        for _ in 0..<count {
            now = BoostEngine.nextBoundary(of: window, after: now, calendar: berlin)
            found.append(now)
        }
        return found
    }

    // MARK: Daylight saving (C-BOOST-10)

    /// Autumn (2026-10-25, 03:00 → 02:00): an overnight window ends at 06:00 and starts at 22:00 local time, not an
    /// hour early, and no start is skipped.
    @Test func anOvernightWindowOnTheAutumnDay() {
        let window = ScheduleWindow(startMinute: 22 * 60, endMinute: 6 * 60)
        #expect(boundaries(window, from: date(2026, 10, 25, 0, 30), count: 3)
                == [date(2026, 10, 25, 6), date(2026, 10, 25, 22), date(2026, 10, 26, 6)])
    }

    /// Autumn and spring with a daytime window: 08:00 and 20:00 local time on the day itself and the day after.
    @Test func aDaytimeWindowOnBothDaylightSavingDays() {
        let window = ScheduleWindow(startMinute: 8 * 60, endMinute: 20 * 60)
        #expect(boundaries(window, from: date(2026, 10, 25, 0, 30), count: 3)
                == [date(2026, 10, 25, 8), date(2026, 10, 25, 20), date(2026, 10, 26, 8)])
        #expect(boundaries(window, from: date(2026, 3, 29, 0, 30), count: 4)
                == [date(2026, 3, 29, 8), date(2026, 3, 29, 20), date(2026, 3, 30, 8), date(2026, 3, 30, 20)])
    }

    /// A boundary inside the spring gap (02:30 does not exist on 2026-03-29) is the first time after it; a boundary
    /// exactly now counts as the next day.
    @Test func aMissingTimeAndABoundaryExactlyNow() {
        let window = ScheduleWindow(startMinute: 2 * 60 + 30, endMinute: 20 * 60)
        #expect(BoostEngine.nextBoundary(of: window, after: date(2026, 3, 29, 1), calendar: berlin)
                == date(2026, 3, 29, 3))
        let daytime = ScheduleWindow(startMinute: 8 * 60, endMinute: 20 * 60)
        #expect(BoostEngine.nextBoundary(of: daytime, after: date(2026, 5, 8, 8), calendar: berlin)
                == date(2026, 5, 8, 20))
    }

    // MARK: Chunked deadlines (C-BOOST-11)

    /// "Pause for 1 Hour" sleeps at most 5 min at a time, so a wall-clock jump (the user set the time, a sync after
    /// sleep) ends it within one chunk instead of an hour later.
    @Test func aPauseFollowsTheWallClock() async throws {
        let h = EngineHarness()
        await h.start()
        #expect(await h.boost())
        let until = h.time.wallClock.addingTimeInterval(3_600)
        h.engine.pause(until: until, source: .menu)
        await h.advance(.seconds(1))                                      // the deadline task sleeps its first chunk
        #expect(h.engine.pauseSlot.isRunning && h.settings[AutomationSettings.pausedUntil] == until)
        let jumpedAt = h.time.now.sinceOrigin.timeInterval
        h.time.setWallClock(until.addingTimeInterval(-10))                // the clock moved 59 min forward
        await h.advance(.seconds(310), step: .seconds(5))                  // one 5 min chunk and a little
        #expect(h.settings[AutomationSettings.pausedUntil] == nil && h.codes.contains("pause.ended"))
        let ended = try #require(h.journal.snapshot().last { $0.code == "pause.ended" })
        #expect(ended.seconds - jumpedAt <= 301)                          // within one chunk
        #expect(await h.boost())
    }

    /// The auto-off ends on time across many chunks, with nothing left running.
    @Test func autoOffEndsOnTimeAcrossChunks() async throws {
        let h = EngineHarness()
        h.settings[AutomationSettings.autoOffMinutes] = 30
        await h.start()
        #expect(await h.boost())
        let deadline = try #require(h.engine.status.autoOffAt)
        await h.advance(.seconds(29 * 60), step: .seconds(5))
        #expect(h.engine.status.isOn)
        let left = deadline.timeIntervalSince(h.time.wallClock)
        await h.advance(.seconds(left + 1), step: .milliseconds(500))
        #expect(!h.engine.status.isOn && h.engine.status.lastChange?.kind == .timerEnded)
        #expect(!h.engine.autoOffSlot.isRunning)
    }
}
