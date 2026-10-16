// OverbrightBoost/SelfTest/SelfTestRunner.swift — Advanced ▸ Run Self-Test. ARCHITECTURE.md §8.4; DESIGN.md §10.
// Thread: main. Owned by WP5 (seeded by WP0a with the §10.0 signatures).
//
// For each chosen display (the engine has returned every display to Standard and holds the master off): read H0 (three
// reads 100 ms apart), arm one rung through the display's driver with the table at its baseline, record H at 10 Hz for
// `secondsPerStrategy`, remove the rung, judge it (`HeadroomTrace`), and go on: through every rung ("Test every
// method"), or until the first that holds. It measures triggers only: it never asks for a table factor, so it never
// writes a scaled table. Cancelling the task that awaits `run` is Stop: everything returns to Standard at once and the
// report holds what was measured. Every async step is guarded by its own generation counter (§4.6).
import Foundation
import OverbrightCore
import os

private let log = Log.logger(.selfTest)

/// Measures every rung on the chosen displays through their drivers and returns a `SelfTestReport`.
public final class SelfTestRunner {
    /// Pause after removing a rung, so its grant has gone before the next baseline is read.
    static let settleAfterRung: Duration = .seconds(1)

    private let drivers: [any DisplayControllerDriving]
    private let time: any TimeSource
    private let journal: any DiagnosticsJournal
    private let machine: MachineIdentity
    private var generation: UInt64 = 0
    private var isRunning = false

    /// A runner over one driver per display.
    public init(drivers: [any DisplayControllerDriving], time: any TimeSource, journal: any DiagnosticsJournal,
                machine: MachineIdentity) {
        self.drivers = drivers; self.time = time; self.journal = journal; self.machine = machine
    }

    /// Runs the test and returns the report (a second call while one runs returns an empty report). Cancel the
    /// calling task to stop: every display is back at Standard when this returns, whatever happened.
    public func run(_ options: SelfTestOptions) async -> SelfTestReport {
        let startedAt = time.wallClock
        guard !isRunning else { return report(startedAt: startedAt, displays: [:], since: .infinity) }
        isRunning = true
        generation &+= 1
        let runGeneration = generation
        let since = time.now.sinceOrigin.timeInterval
        let chosen = drivers.filter { options.displays?.contains($0.display.key) ?? true }
        record("selftest.started", values: ["displays": Double(chosen.count),
                                            "everyStrategy": options.everyStrategy ? 1 : 0,
                                            "seconds": Double(options.secondsPerStrategy)])
        log.info("self-test: \(chosen.count, privacy: .public) display(s)")

        var results: [String: [SelfTestStrategyResult]] = [:]
        var stopped = false
        for driver in chosen where !stopped {
            let measured = await measure(driver, options: options, generation: runGeneration)
            results[driver.display.key.rawValue] = measured.results
            stopped = measured.stopped
        }
        for driver in chosen { driver.returnToStandard() }        // every trigger removed, every display neutral
        record(stopped ? "selftest.stopped" : "selftest.finished")
        isRunning = false
        return report(startedAt: startedAt, displays: results, since: since)
    }

    /// The rung to cache after a clean pass (DESIGN.md §10: "the cache is updated only from a clean pass"): the first
    /// that held, provided no rung of the display was judged on an invalid (pre-held) baseline.
    public static func cleanWinner(in results: [SelfTestStrategyResult]) -> SelfTestStrategyResult? {
        guard !results.contains(where: { $0.verdict == .invalidBaseline }) else { return nil }
        return results.first { $0.verdict == .held }
    }

    // MARK: One display

    private func measure(_ driver: any DisplayControllerDriving, options: SelfTestOptions,
                         generation runGeneration: UInt64) async -> (results: [SelfTestStrategyResult], stopped: Bool) {
        let key = driver.display.key
        guard let first = driver.readHeadroom() else {
            record("selftest.noReading", display: key)
            let rungs = MeasurementLadder.rungs(everyStrategy: options.everyStrategy, machine: machine, headroomTag: 1)
            return (rungs.map { Self.skipped($0, baseline: 0) }, false)
        }
        let rungs = MeasurementLadder.rungs(everyStrategy: options.everyStrategy, machine: machine,
                                            headroomTag: first.potential)
        var results: [SelfTestStrategyResult] = []
        for (index, rung) in rungs.enumerated() {
            guard rung.isAvailable else {
                results.append(Self.skipped(rung, baseline: first.current))
                continue
            }
            do {
                let result = try await measure(rung, on: driver, seconds: options.secondsPerStrategy,
                                               generation: runGeneration)
                results.append(result)
                record("selftest.\(result.verdict.rawValue)", display: key, values: values(of: result, rung: index))
                if !options.everyStrategy, result.verdict == .held || result.verdict == .invalidBaseline { break }
            } catch {
                return (results, true)                              // Stop (cancelled) or superseded
            }
        }
        return (results, false)
    }

    /// Baseline, arm, sample at 10 Hz, remove, settle. Throws when the task is cancelled or a newer run started.
    private func measure(_ rung: MeasurementRung, on driver: any DisplayControllerDriving, seconds: Int,
                         generation runGeneration: UInt64) async throws -> SelfTestStrategyResult {
        var reads: [Double] = [], potential = 0.0
        for index in 0..<EngineTiming.baselineReads {
            if index > 0 { try await sleep(EngineTiming.baselineReadInterval, generation: runGeneration) }
            if let reading = driver.readHeadroom() { reads.append(reading.current); potential = reading.potential }
        }
        guard !reads.isEmpty else { return Self.skipped(rung, baseline: 0) }
        var trace = HeadroomTrace(baselineReads: reads)
        if trace.isPreHeld {                                        // cannot be judged: never armed
            return result(rung, trace: trace, samples: [])
        }
        guard await driver.arm(rung: rung.request) else {
            record("selftest.armFailed", display: driver.display.key)
            await driver.disarm()
            return Self.skipped(rung, baseline: trace.baseline)
        }
        let start = time.now
        var samples = [SelfTestSample(seconds: 0, current: trace.baseline, potential: potential, appliedFactor: 1,
                                      event: "present")]
        let duration = Duration.seconds(max(seconds, 1))
        while time.now - start < duration {                         // a throw leaves it to the caller's Standard
            try await sleep(EngineTiming.gatePollInterval, generation: runGeneration)
            let t = (time.now - start).timeInterval
            guard let reading = driver.readHeadroom() else {
                samples.append(SelfTestSample(seconds: t, current: 0, potential: 0, appliedFactor: 1, event: "noReading"))
                continue
            }
            let moved = trace.firstMovement != nil, stable = trace.firstStable != nil
            trace.append(seconds: t, headroom: reading.current)
            let event = !moved && trace.firstMovement != nil ? "movement"
                : !stable && trace.firstStable != nil ? "stable" : nil
            samples.append(SelfTestSample(seconds: t, current: reading.current, potential: reading.potential,
                                          appliedFactor: 1, event: event))
        }
        await driver.disarm()
        samples.append(SelfTestSample(seconds: (time.now - start).timeInterval,
                                      current: trace.points.last?.headroom ?? 0, potential: potential,
                                      appliedFactor: 1, event: "removed"))
        try await sleep(Self.settleAfterRung, generation: runGeneration)
        return result(rung, trace: trace, samples: samples)
    }

    // MARK: Helpers

    private func sleep(_ duration: Duration, generation runGeneration: UInt64) async throws {
        try await time.sleep(for: duration)
        guard runGeneration == generation else { throw CancellationError() }
    }

    private func result(_ rung: MeasurementRung, trace: HeadroomTrace, samples: [SelfTestSample])
        -> SelfTestStrategyResult {
        SelfTestStrategyResult(strategy: rung.request.strategy, pixel: rung.request.pixel, verdict: trace.verdict,
                               baselineHeadroom: trace.baseline, secondsToFirstMovement: trace.firstMovement,
                               secondsToStable: trace.firstStable, heldFraction: trace.heldFraction,
                               samples: samples)
    }

    private static func skipped(_ rung: MeasurementRung, baseline: Double) -> SelfTestStrategyResult {
        SelfTestStrategyResult(strategy: rung.request.strategy, pixel: rung.request.pixel, verdict: .skipped,
                               baselineHeadroom: baseline, secondsToFirstMovement: nil, secondsToStable: nil,
                               heldFraction: 0, samples: [])
    }

    private func values(of result: SelfTestStrategyResult, rung: Int) -> [String: Double] {
        var values = ["rung": Double(rung), "baseline": result.baselineHeadroom, "held": result.heldFraction]
        values["movement"] = result.secondsToFirstMovement
        values["stable"] = result.secondsToStable
        return values
    }

    private func report(startedAt: Date, displays: [String: [SelfTestStrategyResult]], since: Double)
        -> SelfTestReport {
        SelfTestReport(startedAt: startedAt, machine: machine, appVersion: AppInfo.current().version,
                       displays: displays, journal: journal.snapshot().filter { $0.seconds >= since })
    }

    private func record(_ code: String, display: DisplayKey? = nil, values: [String: Double] = [:]) {
        journal.record(JournalEvent(seconds: time.now.sinceOrigin.timeInterval, category: LogCategory.selfTest.rawValue,
                                    display: display?.rawValue, code: code, values: values))
    }
}
