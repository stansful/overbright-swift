// OverbrightCoreTests/TimeSourceGridTests.swift — the shared grid of a time source (`TimeSource.nextGridPoint(every:)`,
// `MonotonicInstant.nextGridPoint(after:every:)`): the next multiple of the period since the origin strictly after now,
// so the wait is always in (0, period] and never longer than the period it replaces. ARCHITECTURE.md §3.6.
import Foundation
import OverbrightTestSupport
import Testing
@testable import OverbrightCore

@Suite struct TimeSourceGridTests {
    private let period: Duration = .seconds(2)

    private func at(_ duration: Duration) -> MonotonicInstant { MonotonicInstant(sinceOrigin: duration) }

    private func next(_ duration: Duration, every period: Duration = .seconds(2)) -> MonotonicInstant {
        MonotonicInstant.nextGridPoint(after: at(duration), every: period)
    }

    /// Whether `instant` is a whole number of `period`s from the origin (exact `Duration` arithmetic).
    private func isOnGrid(_ instant: MonotonicInstant, every period: Duration) -> Bool {
        let periods = (instant.sinceOrigin / period).rounded()
        return period * Int64(periods) == instant.sinceOrigin
    }

    @Test func onAGridPointItIsTheNextOne() {
        #expect(next(.zero) == at(.seconds(2)))
        #expect(next(.seconds(4)) == at(.seconds(6)))
        #expect(next(.milliseconds(50), every: .milliseconds(50)) == at(.milliseconds(100)))
    }

    @Test func justAfterAGridPointItIsAlmostAWholePeriodAway() {
        #expect(next(.seconds(4) + .nanoseconds(1)) == at(.seconds(6)))
        #expect(next(.seconds(4) + .milliseconds(1)) == at(.seconds(6)))
        #expect(next(Duration(secondsComponent: 4, attosecondsComponent: 1)) == at(.seconds(6)))
    }

    @Test func justBeforeAGridPointItIsThatPoint() {
        #expect(next(.seconds(6) - .nanoseconds(1)) == at(.seconds(6)))
        #expect(next(.milliseconds(5_999)) == at(.seconds(6)))
        #expect(next(Duration(secondsComponent: 5, attosecondsComponent: 999_999_999_999_999_999)) == at(.seconds(6)))
    }

    @Test func beforeTheOriginTheGridContinues() {
        #expect(next(.milliseconds(-500)) == at(.zero))
        #expect(next(.seconds(-2)) == at(.zero))
        #expect(next(.milliseconds(-2_500)) == at(.seconds(-2)))
    }

    /// A period that is not positive has no grid: the instant itself, never a point before it.
    @Test func aPeriodThatIsNotPositiveHasNoGrid() {
        #expect(next(.seconds(3), every: .zero) == at(.seconds(3)))
        #expect(next(.seconds(3), every: .seconds(-2)) == at(.seconds(3)))
    }

    /// 10 000 seeded instants (attosecond precision, up to 30 years of uptime, before and after the origin) and the
    /// periods of the 2 s activities and of the tests' shortened ones: the point is strictly after the instant, at most
    /// one period away, and on the grid.
    @Test func thePointIsAlwaysOnTheGridWithinOnePeriod() {
        var generator = SeededGenerator(seed: 0x6772_6964)
        let periods: [Duration] = [.seconds(2), .milliseconds(50), .milliseconds(40), .milliseconds(1_500),
                                   .milliseconds(5)]
        for _ in 0..<10_000 {
            let seconds = Int64.random(in: -1_000...1_000_000_000, using: &generator)
            let attoseconds = Int64.random(in: 0..<1_000_000_000_000_000_000, using: &generator)
            let now = at(Duration(secondsComponent: seconds, attosecondsComponent: attoseconds))
            let period = periods.randomElement(using: &generator) ?? .seconds(2)
            let point = MonotonicInstant.nextGridPoint(after: now, every: period)
            #expect(point > now && point - now <= period, "\(now.sinceOrigin) every \(period) → \(point.sinceOrigin)")
            #expect(isOnGrid(point, every: period), "\(now.sinceOrigin) every \(period) → \(point.sinceOrigin)")
        }
    }

    /// Past 2^52 periods a Double no longer counts single periods: the point is then one period away, still within
    /// the bound.
    @Test func farBeyondAnyUptimeTheBoundStillHolds() {
        let now = at(.seconds(Int64(1) << 62))
        let point = MonotonicInstant.nextGridPoint(after: now, every: .nanoseconds(3))
        #expect(point > now && point - now <= .nanoseconds(3))
    }

    /// Every conformer has the helper as is; on the manual clock it follows `advance(by:)`.
    @Test func everyTimeSourceHasTheGridOfItsOwnClock() async {
        let time = ManualTimeSource()
        #expect(time.nextGridPoint(every: period) == at(.seconds(2)))
        await time.advance(by: .milliseconds(3_500))
        #expect(time.nextGridPoint(every: period) == at(.seconds(4)))
        await time.advance(by: .milliseconds(500))
        #expect(time.nextGridPoint(every: period) == at(.seconds(6)))
        let system = SystemTimeSource()
        let before = system.now
        let point = system.nextGridPoint(every: period)
        #expect(point > before && point - system.now <= period && isOnGrid(point, every: period))
    }
}
