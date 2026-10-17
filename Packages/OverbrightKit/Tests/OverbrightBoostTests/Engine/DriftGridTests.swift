// OverbrightBoostTests/Engine/DriftGridTests.swift — the drift checks sleep to the shared 2 s grid of the engine's time
// source (D29, ARCHITECTURE.md §4.8): every tick of every display lands on a multiple of 2 s of the ManualTimeSource's
// origin, however their ramps ended, and the first tick after a ramp comes at most 2 s after it settled (D9's interval
// never grows). Ticks are the table reads `CountingGammaPort` logs; the 50 ms check after an exit stays relative.
import CoreGraphics
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct DriftGridTests {
    private static let period = EngineTiming.watchdogInterval

    private func harness(_ fixture: DisplayFixture = .russianNames) -> (EngineHarness, CountingGammaPort) {
        var port: CountingGammaPort?
        let h = EngineHarness(fixture: fixture, wrapGamma: { gamma, time in
            let counting = CountingGammaPort(gamma, time: time)
            port = counting
            return counting
        })
        return (h, port!)
    }

    private static func isOnGrid(_ instant: MonotonicInstant) -> Bool {
        MonotonicInstant.nextGridPoint(after: instant, every: period) == instant + period
    }

    /// The wait from `instant` to the next point of the grid (Core's rule, `TimeSourceGridTests`).
    private static func toGrid(_ instant: MonotonicInstant) -> Duration {
        MonotonicInstant.nextGridPoint(after: instant, every: period) - instant
    }

    // MARK: The grid rule

    /// The drift loop sleeps to `TimeSource.nextGridPoint` of the engine's time source (the rule itself is Core's,
    /// `TimeSourceGridTests`): with the clock off whole nanoseconds, every drift read still lands exactly on a grid
    /// point, never before it and never twice on one.
    @Test func aClockOffWholeNanosecondsStillTicksExactlyOnTheGrid() async throws {
        let (h, port) = harness(.builtinXDRLidOpen)
        await h.start()
        #expect(await h.boost())
        await h.advance(Duration(secondsComponent: 0, attosecondsComponent: 1) + .milliseconds(1_370))
        #expect(!Self.isOnGrid(h.time.now))
        await h.advance(.seconds(3))                                      // any recovery burst is over
        port.resetCounts()
        await h.advance(.seconds(20), step: .milliseconds(100))
        let times = port.reads.map(\.time)
        #expect(times.count == 10, "\(times.count) drift reads in 20 s")
        #expect(times.allSatisfy(Self.isOnGrid), "\(times.map(\.sinceOrigin).prefix(6))")
        #expect(Set(times).count == times.count)
        #expect(h.phase() == .boosted)
    }

    // MARK: In the engine

    /// Two displays whose ramps end at different times (a boost, then a dim 0.73 s later): after both settled, every
    /// drift read of either lands on a multiple of 2 s, each display once per grid point, and each display's first
    /// tick came at most 2 s after it settled.
    @Test func twoDisplaysTickTogetherOnTheGrid() async throws {
        let (h, port) = harness()
        let msi = DisplayFixture.Keys.mpg322ux
        await h.start()
        #expect(await h.boost(h.builtIn))
        let builtInSettled = h.time.now
        await h.advance(.milliseconds(730))
        h.engine.setLevel(LevelPosition(-0.5), for: msi, source: .panel)
        #expect(await h.advance(until: { h.phase(msi) == .dimmed }))
        let msiSettled = h.time.now
        // Relative 2 s sleeps would have put the two displays' ticks on different phases.
        #expect(Self.toGrid(builtInSettled) != Self.toGrid(msiSettled))
        await h.advance(.milliseconds(2_100))
        let firstBuiltIn = try #require(port.reads.first { $0.display == h.id(h.builtIn) && $0.time > builtInSettled })
        let firstMSI = try #require(port.reads.first { $0.display == h.id(msi) && $0.time > msiSettled })
        #expect(firstBuiltIn.time - builtInSettled <= Self.period)
        #expect(firstMSI.time - msiSettled <= Self.period)

        await h.advance(.seconds(3))                                      // any recovery burst is over
        port.resetCounts()
        let from = h.time.now
        await h.advance(.seconds(20), step: .milliseconds(100))
        let reads = port.reads
        #expect(reads.allSatisfy { Self.isOnGrid($0.time) }, "\(reads.map(\.time.sinceOrigin).prefix(8))")
        for key in [h.builtIn, msi] {
            let times = reads.filter { $0.display == h.id(key) }.map(\.time)
            #expect(times.count == 10, "\(key.rawValue): \(times.count) ticks")
            #expect(Set(times).count == times.count)                      // never twice on one grid point
        }
        #expect(Set(reads.map(\.time)).count == 10)                       // both displays on the same 10 points
        #expect(reads.allSatisfy { $0.time > from })
        #expect(h.phase(h.builtIn) == .boosted && h.phase(msi) == .dimmed)
    }

    /// The check 50 ms after an exit is not on the grid (§4.8): it stays relative to the termination.
    @Test func theExitCheckStaysRelative() async throws {
        let (h, port) = harness(.builtinXDRLidOpen)
        await h.start()
        #expect(await h.boost())
        await h.advance(.seconds(4))
        await h.advance(.milliseconds(330))                               // off the grid
        port.resetCounts()
        let exited = h.time.now
        h.signals.emit(.appTerminated(bundleID: "com.example.tool", processID: 77))
        await h.advance(.milliseconds(60), step: .milliseconds(5))
        let read = try #require(port.reads.first)
        #expect(read.time - exited == EngineTiming.appTerminationCheckDelay)
        #expect(!Self.isOnGrid(read.time))
    }
}
