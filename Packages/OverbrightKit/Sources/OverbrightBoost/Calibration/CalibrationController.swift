// OverbrightBoost/Calibration/CalibrationController.swift — one running calibration. ARCHITECTURE.md §5.2, §5.6, §5.8;
// DESIGN.md §9. Thread: main. Owned by WP5 (seeded by WP0a with the §10.0 signatures).
//
// `begin()` returns the display to Standard, shows the cheapest rung that makes macOS grant extra range and waits for a
// stable grant (the gate of D6, `HeadroomTrace`). Step 1 flips between Standard and ×1.3 light, at most once per 1.5 s.
// Step 2 raises the table factor from 1.00 in 0.02 steps every 0.4 s on the black-surround pattern, pauses at 1.15 × the
// encoded prediction until "Keep Going", and ends at Space (the merge), at 1.15 × the linear prediction, or early. Step 3,
// only after a merge near the linear prediction, shows the patches for 2 s at 0.97 × H. Every factor goes through the
// driver (`TableWriter.writeCalibrationFactor`, which refuses anything above `maxFactor` or the reading's calibration
// ceiling, a stale reading and a stale hang epoch; in Compatibility mode the overlay's factor under the same checks).
// The display returns to Standard at once on Esc, a lock, occlusion, a headroom drop, the 60 s limit or a refused write
// (a hang restore refuses every later write). `finish(brighter:)` applies the decision rule (`CalibrationMath`) and
// returns the record, keyed by OS build, mechanism and potential; after an abort it records nothing unless the sweep had
// ended with a mark or the confirmation was answered (§11.1 #35: an earlier record stays). Every async step carries the
// session's generation (§4.6). The three steps live in `CalibrationController+Steps.swift`.
import Foundation
import Observation
import OverbrightCore
import OverbrightPolicy
import os

private let log = Log.logger(.engine)

/// Implements `CalibrationSession` for one display; every table write goes through `writer`'s interlock (via the
/// driver). Observable, so the calibration window follows `state`, `currentFactor` and the pause.
@Observable public final class CalibrationController: CalibrationSession {
    /// The display under test.
    public let display: DisplayKey
    /// The table factor shown now.
    public internal(set) var currentFactor: Double = 1
    /// The latest headroom of the display.
    public private(set) var headroom: Double?
    /// True while the sweep waits at 1.15 × the encoded prediction for "Keep Going".
    public internal(set) var isSweepPausedAtLimit = false
    /// The step the session is in.
    public internal(set) var state: CalibrationState = .preparing
    /// The mechanism measured (the engine sets `.overlay` on a Compatibility-mode display before `begin()`); a record
    /// never carries over to the other mechanism.
    public var mechanism: Mechanism = .table
    /// Called once when the session ends (finished or aborted), so the engine can release the master.
    @ObservationIgnored public var onEnd: (() -> Void)?

    let driver: any DisplayControllerDriving
    let writer: TableWriter
    let time: any TimeSource
    let machine: MachineIdentity

    @ObservationIgnored var generation: UInt64 = 0
    @ObservationIgnored var began = false
    @ObservationIgnored var ended = false
    @ObservationIgnored var work: Task<Void, Never>?
    @ObservationIgnored var pendingComparison: Bool?
    @ObservationIgnored var pendingSweep = false
    @ObservationIgnored var lastFlip: MonotonicInstant?
    @ObservationIgnored var flipTask: Task<Void, Never>?
    /// H when the grant became stable; the reference of the drop check until the sweep starts.
    @ObservationIgnored var readyHeadroom: Double?
    @ObservationIgnored var potential: Double?
    /// H at the sweep's start: the predictions and the record use it.
    @ObservationIgnored var sweepHeadroom: Double?
    @ObservationIgnored var sweepStart: MonotonicInstant?
    @ObservationIgnored var pauseAcknowledged = false
    @ObservationIgnored var mergeFactor: Double?
    @ObservationIgnored var sweepRan = false
    @ObservationIgnored var confirmationShown = false
    @ObservationIgnored var linearConfirmed: Bool?
    @ObservationIgnored var measuredSDRWhite: Double?
    @ObservationIgnored var record: CalibrationRecord?

    /// A session for `display`, driven through `driver`.
    public init(display: DisplayKey, driver: any DisplayControllerDriving, writer: TableWriter, time: any TimeSource,
                machine: MachineIdentity) {
        self.display = display; self.driver = driver; self.writer = writer; self.time = time; self.machine = machine
    }

    // MARK: Start

    /// Returns the display to Standard and arms it; the state becomes `.ready` once macOS grants stable extra range (or
    /// `.aborted(.noExtraRange)`). The first comparison or sweep calls it when the engine did not.
    public func begin() {
        guard !began, !ended else { return }
        began = true
        driver.returnToStandard()
        currentFactor = 1
        journal("calibration.began")
        let g = generation
        work = Task { [weak self] in await self?.prepare(generation: g) }
    }

    private func prepare(generation g: UInt64) async {
        var reads: [Double] = []
        for index in 0..<EngineTiming.baselineReads {
            if index > 0 { guard await sleep(EngineTiming.baselineReadInterval, generation: g) else { return } }
            if let reading = driver.readHeadroom() {
                reads.append(reading.current)
                potential = reading.potential
                headroom = reading.current
            }
        }
        guard !reads.isEmpty, let potential, potential > 1.01 else { return abort(.noExtraRange) }
        var rungs = MeasurementLadder.rungs(everyStrategy: false, machine: machine, headroomTag: potential)
            .filter(\.isAvailable)
        // Compatibility mode: the overlay is the one EDR request; the rung only carries the headroom tag it asks for.
        if mechanism == .overlay { rungs = Array(rungs.prefix(1)) }
        for (index, rung) in rungs.enumerated() {
            let armed = await driver.arm(rung: rung.request)
            guard g == generation, !ended else { return }
            guard armed else { continue }
            var trace = HeadroomTrace(baselineReads: reads)
            let start = time.now
            while true {
                guard await sleep(EngineTiming.gatePollInterval, generation: g) else { return }
                guard let reading = driver.readHeadroom() else { return abort(.displayGone) }
                headroom = reading.current
                let elapsed = (time.now - start).timeInterval
                trace.append(seconds: elapsed, headroom: reading.current)
                if trace.firstStable != nil {
                    readyHeadroom = reading.current
                    state = .ready
                    journal("calibration.ready", values: ["headroom": reading.current, "rung": Double(index)])
                    return resumePending()
                }
                let sinceMovement = elapsed - (trace.firstMovement ?? 0)
                let rungTimedOut = elapsed >= EngineTiming.rungTimeout.timeInterval
                if trace.firstMovement == nil, !trace.isPreHeld, rungTimedOut { break }
                if sinceMovement >= EngineTiming.gateTimeout.timeInterval { break }
            }
            await driver.disarm()
            guard g == generation else { return }
        }
        abort(.noExtraRange)
    }

    func resumePending() {
        if pendingSweep {
            pendingSweep = false
            startSweep()
        } else if let boosted = pendingComparison {
            pendingComparison = nil
            showComparison(boosted: boosted)
        }
    }

    // MARK: Results

    /// A colorimeter reading of SDR white at Standard, or nil; an implausible value is ignored.
    public func setMeasuredSDRWhite(nits: Double?) {
        guard let nits else { measuredSDRWhite = nil; return }
        guard nits.isFinite, CalibrationMath.plausibleSDRWhite.contains(nits) else { return }
        measuredSDRWhite = nits
    }

    /// Ends the session (Standard at once) and returns the record: `.notBrighter` when the screen did not get brighter,
    /// else the decision rule; nil when nothing was measured. After an abort (Esc mid-sweep, a lock, occlusion, a
    /// headroom drop, a refused write) it is nil too unless the sweep had ended with a mark or the confirmation was
    /// answered, so an interrupted run never replaces an earlier record with `.inconclusive` (§11.1 #35). A second
    /// call returns the same record.
    public func finish(brighter: Bool?) -> CalibrationRecord? {
        if case .finished = state { return record }
        let aborted = if case .aborted = state { true } else { false }
        end()
        state = .finished
        let measured = aborted
            ? brighter == false || mergeFactor != nil || linearConfirmed != nil
            : brighter != nil || sweepRan || measuredSDRWhite != nil
        guard measured else {
            notifyEnd()
            return nil
        }
        let h = sweepHeadroom ?? readyHeadroom ?? headroom ?? 1
        let outcome: CalibrationRecord.Outcome = brighter == false ? .notBrighter
            : CalibrationMath.outcome(merge: sweepRan ? mergeFactor : nil, headroom: h, linearConfirmed: linearConfirmed)
        let merge = brighter == false ? nil : mergeFactor
        let result = CalibrationRecord(
            outcome: outcome, mechanism: mechanism, mergeFactor: merge,
            estimatedExponent: CalibrationMath.estimatedExponent(headroom: h, mergeFactor: merge),
            measuredSDRWhiteNits: measuredSDRWhite, headroomAtTest: h, potentialAtTest: potential ?? 1,
            osBuild: machine.osBuild, measuredAt: time.wallClock)
        record = result
        journal("calibration.finished.\(outcome.rawValue)", values: ["headroom": h, "merge": mergeFactor ?? 0])
        notifyEnd()
        return result
    }

    /// Esc: Standard at once; the session ends.
    public func cancel() { abort(.cancelled) }

    // MARK: Events (forwarded by the engine and the calibration window)

    /// Ends the session early with `reason`; the display is back at Standard when this returns.
    public func abort(_ reason: CalibrationAbortReason) {
        guard !ended else { return }
        end()
        state = .aborted(reason)
        journal("calibration.aborted.\(reason.rawValue)")
        log.info("calibration aborted: \(reason.rawValue, privacy: .public)")
        notifyEnd()
    }

    /// Shield events and the removal of this display end the session (DESIGN.md §9: any lock).
    public func handle(_ event: SystemEvent) {
        switch event {
        case .locked, .screensaverStarted, .willSleep, .screensDidSleep, .sessionResigned:
            abort(.shielded)
        case .displayRemoved(let id) where id == driver.display.id:
            abort(.displayGone)
        default:
            break
        }
    }

    /// The calibration window or the trigger was hidden.
    public func setOccluded(_ occluded: Bool) {
        if occluded { abort(.occluded) }
    }

    // MARK: Helpers

    /// Stops every task and returns the display to Standard, once.
    func end() {
        guard !ended else { return }
        ended = true
        generation &+= 1
        work?.cancel()
        flipTask?.cancel()
        work = nil
        flipTask = nil
        isSweepPausedAtLimit = false
        if began { driver.returnToStandard() }
        currentFactor = 1
    }

    /// Calls `onEnd` once, after the final state is set.
    func notifyEnd() {
        let callback = onEnd
        onEnd = nil
        callback?()
    }

    /// One factor through the driver; a refusal ends the session.
    func write(_ factor: Double, maxFactor: Double) -> Bool {
        do {
            try driver.writeCalibrationFactor(factor, maxFactor: maxFactor)
            currentFactor = factor
            return true
        } catch {
            abort(.writeRefused)
            return false
        }
    }

    /// A fresh reading that has not fallen below 95 % of `reference`; otherwise the session ends and nil is returned.
    func freshReading(reference: Double?) -> HeadroomReading? {
        guard let reading = driver.readHeadroom() else {
            abort(.displayGone)
            return nil
        }
        headroom = reading.current
        if let reference, reading.current < CalibrationMath.headroomDropLimit * reference {
            abort(.headroomDropped)
            return nil
        }
        return reading
    }

    /// Sleeps; false when the sleep was cancelled or the session moved on (a newer generation).
    func sleep(_ duration: Duration, generation g: UInt64) async -> Bool {
        do { try await time.sleep(for: duration) } catch { return false }
        return g == generation && !ended
    }

    func journal(_ code: String, values: [String: Double] = [:]) {
        writer.journal.record(JournalEvent(seconds: time.now.sinceOrigin.timeInterval,
                                           category: LogCategory.engine.rawValue, display: display.rawValue,
                                           code: code, values: values))
    }
}
