// OverbrightBoostTests/SelfTest/SelfTestRunnerTests.swift — the self-test (ARCHITECTURE.md §8.4, §10.7; DESIGN.md §10):
// scripted headroom gives each verdict (held, engaged but dropped, no engage, invalid baseline when pre-held, skipped),
// the ladder runs from the top and stops at the first that holds unless every method is tested, nothing is ever
// scaled, Stop returns to Standard at once, and the report carries the machine and the test's journal.
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct SelfTestRunnerTests {
    /// Holds the report a run returns.
    @MainActor final class Outcome { var report: SelfTestReport? }

    private let builtIn = DisplayFixture.Keys.builtIn

    private func runner(_ rig: DriverRig, machine: MachineIdentity? = nil) -> SelfTestRunner {
        SelfTestRunner(drivers: rig.drivers, time: rig.time, journal: rig.journal, machine: machine ?? rig.fixture.machine)
    }

    /// Runs the test to its end on the manual clock.
    private func run(_ rig: DriverRig, _ options: SelfTestOptions, machine: MachineIdentity? = nil,
                     each: (Duration) -> Void = { _ in }) async throws -> SelfTestReport {
        let runner = runner(rig, machine: machine)
        let outcome = Outcome()
        Task { outcome.report = await runner.run(options) }
        for _ in 0..<10 { await Task.yield() }                       // the run starts before the clock moves
        #expect(await rig.advance(until: { outcome.report != nil }, each: each))
        return try #require(outcome.report)
    }

    // MARK: Verdicts

    @Test func aGrantThatArrivesAndHoldsIsHeldAndEndsTheDefaultTest() async throws {
        let rig = DriverRig()
        let report = try await run(rig, SelfTestOptions(secondsPerStrategy: 6))
        let results = try #require(report.displays[builtIn.rawValue])
        let first = try #require(results.first)
        #expect(results.count == 1)                                   // stopped at the first that holds
        #expect(first.strategy == .taggedLayer && first.pixel == .black && first.verdict == .held)
        #expect(first.baselineHeadroom == 1)
        let movement = try #require(first.secondsToFirstMovement), stable = try #require(first.secondsToStable)
        #expect(movement > 0.15 && movement < 0.5)                    // 0.2 s response delay
        #expect(stable > 2.5 && stable < 3.1)                         // 1 s ramp, then 1.5 s stable
        #expect(first.heldFraction == 1)
        #expect(first.samples.count >= 60 && first.samples.allSatisfy { $0.appliedFactor == 1 })
        #expect(first.samples.contains { $0.event == "movement" } && first.samples.contains { $0.event == "stable" })
        #expect(rig.factory.made.count == 1)
    }

    @Test func noResponseIsNoEngageOnEveryRung() async throws {
        let rig = DriverRig()
        rig.headroom.update(builtIn) { $0.respondingStrategies = [] }
        let report = try await run(rig, SelfTestOptions(secondsPerStrategy: 3))
        let results = try #require(report.displays[builtIn.rawValue])
        #expect(results.count == 7 && results.allSatisfy { $0.verdict == .noEngage })
        #expect(results.allSatisfy { $0.secondsToFirstMovement == nil && $0.heldFraction == 0 })
        #expect(rig.factory.made.count == 7)
    }

    @Test func aGrantThatDropsIsEngagedButDropped() async throws {
        let rig = DriverRig()
        let headroom = rig.headroom, key = builtIn
        let report = try await run(rig, SelfTestOptions(everyStrategy: true, secondsPerStrategy: 6)) { elapsed in
            if elapsed == .seconds(4) { headroom.setOverride(1.0, for: key) }   // stable by now, then lost
        }
        let first = try #require(report.displays[builtIn.rawValue]?.first)
        #expect(first.verdict == .engagedButDropped)
        #expect(first.secondsToStable != nil && first.heldFraction < HeadroomTrace.heldMinimum)
    }

    @Test func aGrantThatNeverSettlesIsEngagedButDropped() async throws {
        let rig = DriverRig()
        rig.headroom.update(builtIn) { $0.rampDuration = .seconds(60) }      // creeps up, never stable
        let report = try await run(rig, SelfTestOptions(secondsPerStrategy: 4))
        let first = try #require(report.displays[builtIn.rawValue]?.first)
        #expect(first.verdict == .engagedButDropped)
        #expect(first.secondsToFirstMovement != nil && first.secondsToStable == nil)
    }

    @Test func aPreHeldBaselineIsInvalidAndNothingIsArmed() async throws {
        let rig = DriverRig()
        rig.headroom.update(builtIn) { $0.preHeld = 2.6 }                      // another app's HDR video
        let report = try await run(rig, SelfTestOptions(secondsPerStrategy: 3))
        let results = try #require(report.displays[builtIn.rawValue])
        #expect(results.map(\.verdict) == [.invalidBaseline])
        #expect(results.first?.baselineHeadroom == 2.6)
        #expect(rig.factory.made.isEmpty)
    }

    @Test func unavailableAndFailingRungsAreSkipped() async throws {
        let rig = DriverRig()
        rig.factory.makeErrors[.metalOneShot] = .noMetalDevice
        let sonoma = MachineIdentity(model: "Mac16,5", osBuild: "23A344", osMajor: 14, osMinor: 0, osPatch: 0)
        let report = try await run(rig, SelfTestOptions(everyStrategy: true, secondsPerStrategy: 3), machine: sonoma)
        let results = try #require(report.displays[builtIn.rawValue])
        #expect(results.map(\.strategy) == [.taggedLayer, .taggedLayer, .metalOneShot, .metalOneShot,
                                            .metalKeepAlive, .hlgSampleBuffer, .hlgStill, .hlgStill])
        #expect(results.map(\.verdict) == [.skipped, .skipped, .skipped, .skipped, .held, .held, .held, .held])
        #expect(!rig.factory.made.contains { $0.request.strategy == .taggedLayer })   // never armed before 26
        #expect(rig.codes.filter { $0 == "selftest.armFailed" }.count == 2)
    }

    // MARK: Safety

    @Test func neverAScaledWriteAndEveryDisplayEndsAtStandard() async throws {
        let rig = DriverRig(.russianNames)
        _ = try await run(rig, SelfTestOptions(everyStrategy: true, secondsPerStrategy: 2))
        for driver in rig.drivers {
            #expect(driver.factors.isEmpty)
            #expect(driver.calls.last == .returnToStandard)
            #expect(rig.gamma.table(of: driver.display.id) == driver.baseline)
        }
        let baselines = Set(rig.drivers.map(\.baseline))
        #expect(rig.gamma.writes.allSatisfy { baselines.contains($0.table) })
        #expect(rig.factory.openWindowCount == 0)
        #expect(rig.factory.made.count == 16)                        // 8 rungs on each of the two displays
    }

    @Test func stopReturnsEverythingToStandardAtOnce() async throws {
        let rig = DriverRig()
        let outcome = Outcome()
        let runner = runner(rig)
        let options = SelfTestOptions(everyStrategy: true, secondsPerStrategy: 5)
        let task = Task { outcome.report = await runner.run(options) }
        var elapsed = Duration.zero
        while elapsed < .seconds(9) {                                 // into the second rung
            await rig.time.advance(by: .milliseconds(100))
            elapsed += .milliseconds(100)
        }
        #expect(rig.factory.openWindowCount == 1)
        task.cancel()
        #expect(await rig.advance(until: { outcome.report != nil }, limit: .seconds(1)))
        let report = try #require(outcome.report)
        #expect(report.displays[builtIn.rawValue]?.count == 1)        // the finished rung only
        #expect(rig.factory.openWindowCount == 0 && rig.driver()?.calls.last == .returnToStandard)
        #expect(rig.codes.contains("selftest.stopped") && !rig.codes.contains("selftest.finished"))
    }

    @Test func aSecondRunWhileOneRunsReturnsAnEmptyReport() async throws {
        let rig = DriverRig()
        let runner = runner(rig)
        let outcome = Outcome()
        Task { outcome.report = await runner.run(SelfTestOptions(secondsPerStrategy: 2)) }
        await rig.time.advance(by: .milliseconds(100))
        let second = await runner.run(SelfTestOptions())
        #expect(second.displays.isEmpty)
        #expect(await rig.advance(until: { outcome.report != nil }))
        #expect(outcome.report?.displays.isEmpty == false)
    }

    // MARK: Displays and the report

    @Test func onlyTheChosenDisplaysAreTested() async throws {
        let rig = DriverRig(.russianNames)
        let msi = DisplayFixture.Keys.mpg322ux
        let report = try await run(rig, SelfTestOptions(secondsPerStrategy: 2, displays: [msi]))
        #expect(Array(report.displays.keys) == [msi.rawValue])
        #expect(rig.driver(builtIn)?.calls.isEmpty == true)
    }

    @Test func aDisplayWithoutItsOwnScreenIsSkipped() async throws {
        let rig = DriverRig(.hardwareMirror)
        let projector = DisplayFixture.Keys.projector
        let report = try await run(rig, SelfTestOptions(secondsPerStrategy: 2, displays: [projector]))
        let results = try #require(report.displays[projector.rawValue])
        #expect(!results.isEmpty && results.allSatisfy { $0.verdict == .skipped })
        #expect(rig.factory.made.isEmpty)
        #expect(rig.codes.contains("selftest.noReading"))
    }

    @Test func theReportCarriesTheMachineAndOnlyThisTestsJournal() async throws {
        let rig = DriverRig()
        rig.journal.record(JournalEvent(seconds: 0, category: "engine", display: nil, code: "earlier.event"))
        await rig.time.advance(by: .seconds(10))
        let report = try await run(rig, SelfTestOptions(secondsPerStrategy: 4))
        #expect(report.machine == rig.fixture.machine)
        #expect(report.startedAt == Date(timeIntervalSinceReferenceDate: 800_000_010))
        let codes = report.journal.map(\.code)
        #expect(codes.first == "selftest.started" && codes.contains("selftest.held") && codes.last == "selftest.finished")
        #expect(!codes.contains("earlier.event"))
        #expect(report.journal.allSatisfy { $0.category == LogCategory.selfTest.rawValue })
    }
}
