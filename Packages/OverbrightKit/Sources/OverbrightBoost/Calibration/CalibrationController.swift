// OverbrightBoost/Calibration/CalibrationController.swift — one running calibration. ARCHITECTURE.md §5.2, §5.6, §5.8;
// DESIGN.md §9. Thread: main. Owned by WP5 (seeded by WP0a with the §10.0 signatures).
//
// `begin()` returns the display to Standard, shows the cheapest rung that makes macOS grant extra range and waits for a
// stable grant (the gate of D6, `HeadroomTrace`). Step 1 flips between Standard and ×1.3 light, at most once per 1.5 s.
// Step 2 raises the table factor from 1.00 in 0.02 steps every 0.4 s on the black-surround pattern, pauses at 1.15 × the
// encoded prediction until "Keep Going", and ends at Space (the merge), at 1.15 × the linear prediction, or early. Step 3,
// only after a merge near the linear prediction, shows the patches for 2 s at 0.97 × H. Every factor goes through the
// driver (`TableWriter.writeCalibrationFactor`, which refuses anything above `maxFactor` or the live interlock). The
// display returns to Standard at once on Esc, a lock, occlusion, a headroom drop, the 60 s limit or a refused write.
// `finish(brighter:)` applies the decision rule (`CalibrationMath`) and returns the record, keyed by OS build, mechanism
// and potential. Every async step carries the session's generation (§4.6).
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
    public private(set) var currentFactor: Double = 1
    /// The latest headroom of the display.
    public private(set) var headroom: Double?
    /// True while the sweep waits at 1.15 × the encoded prediction for "Keep Going".
    public private(set) var isSweepPausedAtLimit = false
    /// The step the session is in.
    public private(set) var state: CalibrationState = .preparing
    /// The mechanism measured (the engine sets `.overlay` on a Compatibility-mode display before `begin()`); a record
    /// never carries over to the other mechanism.
    public var mechanism: Mechanism = .table
    /// Called once when the session ends (finished or aborted), so the engine can release the master.
    @ObservationIgnored public var onEnd: (() -> Void)?

    private let driver: any DisplayControllerDriving
    private let writer: TableWriter
    private let time: any TimeSource
    private let machine: MachineIdentity

    @ObservationIgnored private var generation: UInt64 = 0
    @ObservationIgnored private var began = false
    @ObservationIgnored private var ended = false
    @ObservationIgnored private var work: Task<Void, Never>?
    @ObservationIgnored private var pendingComparison: Bool?
    @ObservationIgnored private var pendingSweep = false
    @ObservationIgnored private var lastFlip: MonotonicInstant?
    @ObservationIgnored private var flipTask: Task<Void, Never>?
    /// H when the grant became stable; the reference of the drop check until the sweep starts.
    @ObservationIgnored private var readyHeadroom: Double?
    @ObservationIgnored private var potential: Double?
    /// H at the sweep's start: the predictions and the record use it.
    @ObservationIgnored private var sweepHeadroom: Double?
    @ObservationIgnored private var sweepStart: MonotonicInstant?
    @ObservationIgnored private var pauseAcknowledged = false
    @ObservationIgnored private var mergeFactor: Double?
    @ObservationIgnored private var sweepRan = false
    @ObservationIgnored private var confirmationShown = false
    @ObservationIgnored private var linearConfirmed: Bool?
    @ObservationIgnored private var measuredSDRWhite: Double?
    @ObservationIgnored private var record: CalibrationRecord?

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
        let rungs = MeasurementLadder.rungs(everyStrategy: false, machine: machine, headroomTag: potential)
        for (index, rung) in rungs.enumerated() where rung.isAvailable {
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

    private func resumePending() {
        if pendingSweep {
            pendingSweep = false
            startSweep()
        } else if let boosted = pendingComparison {
            pendingComparison = nil
            showComparison(boosted: boosted)
        }
    }

    // MARK: Step 1

    /// "Did it get brighter?": Standard or ×1.3 light, at most one flip per 1.5 s (a faster request waits, and the
    /// latest one wins).
    public func showComparison(boosted: Bool) {
        guard !ended else { return }
        switch state {
        case .preparing:
            pendingComparison = boosted
            begin()
            return
        case .ready: break
        default: return
        }
        pendingComparison = boosted
        flipTask?.cancel()
        let wait = lastFlip.map { CalibrationMath.comparisonMinimumInterval - (time.now - $0) } ?? .zero
        guard wait > .zero else { return applyComparison() }
        let g = generation
        flipTask = Task { [weak self] in
            guard let self, await self.sleep(wait, generation: g) else { return }
            self.applyComparison()
        }
    }

    private func applyComparison() {
        guard let boosted = pendingComparison, case .ready = state else { return }
        pendingComparison = nil
        let target: Double
        if boosted {
            guard let reading = freshReading(reference: readyHeadroom) else { return }
            target = CalibrationMath.comparisonFactor(headroom: reading.current)
        } else {
            target = 1
        }
        guard target != currentFactor else { return }
        guard write(target, maxFactor: max(target, 1)) else { return }
        lastFlip = time.now
        journal("calibration.comparison", values: ["factor": target])
        if boosted { watchWhileAboveStandard() }
    }

    /// While step 1 shows the boosted factor, the grant is checked at the sweep's cadence.
    private func watchWhileAboveStandard() {
        let g = generation
        work?.cancel()
        work = Task { [weak self] in
            guard let self else { return }
            while self.currentFactor > 1 {
                guard await self.sleep(CalibrationMath.sweepInterval, generation: g), case .ready = self.state,
                      self.currentFactor > 1, self.freshReading(reference: self.readyHeadroom) != nil else { return }
            }
        }
    }

    // MARK: Step 2

    /// 1.00 → the cap in 0.02 steps every 400 ms on the black surround, pausing at 1.15 × the encoded prediction.
    public func startSweep() {
        guard !ended else { return }
        switch state {
        case .preparing:
            pendingSweep = true
            begin()
            return
        case .ready: break
        default: return
        }
        flipTask?.cancel()
        pendingComparison = nil
        guard let reading = freshReading(reference: readyHeadroom) else { return }
        let h = reading.current
        sweepHeadroom = h
        sweepStart = time.now
        sweepRan = true
        pauseAcknowledged = false
        mergeFactor = nil
        let pauseAt = CalibrationMath.pauseFactor(headroom: h), cap = CalibrationMath.sweepCap(headroom: h)
        guard write(1, maxFactor: cap) else { return }
        state = .sweeping
        journal("calibration.sweep", values: ["headroom": h, "pause": pauseAt, "cap": cap])
        generation &+= 1
        let g = generation
        work?.cancel()
        work = Task { [weak self] in await self?.sweep(pauseAt: pauseAt, cap: cap, generation: g) }
    }

    private func sweep(pauseAt: Double, cap: Double, generation g: UInt64) async {
        var step = 0
        while true {
            guard await sleep(CalibrationMath.sweepInterval, generation: g), case .sweeping = state else { return }
            if let start = sweepStart, time.now - start >= CalibrationMath.sweepTimeLimit { return abort(.timeLimit) }
            guard freshReading(reference: sweepHeadroom) != nil else { return }
            if isSweepPausedAtLimit { continue }
            let next = 1 + Double(step + 1) * CalibrationMath.sweepStep
            if !pauseAcknowledged, next > pauseAt {
                isSweepPausedAtLimit = true
                journal("calibration.paused", values: ["factor": currentFactor])
                continue
            }
            guard next <= cap else { return endSweep(merge: nil) }       // the end of the sweep: nothing marked
            step += 1
            guard write(next, maxFactor: cap) else { return }
        }
    }

    /// Past the pause at 1.15 × the encoded prediction.
    public func continueSweep() {
        guard case .sweeping = state, isSweepPausedAtLimit else { return }
        pauseAcknowledged = true
        isSweepPausedAtLimit = false
        journal("calibration.continued")
    }

    /// Space: the 0.95 patch merged with white at the factor shown now.
    public func markMerged() {
        guard case .sweeping = state else { return }
        endSweep(merge: currentFactor)
    }

    private func endSweep(merge: Double?) {
        generation &+= 1
        work?.cancel()
        isSweepPausedAtLimit = false
        mergeFactor = merge
        guard write(1, maxFactor: 1) else { return }
        let reading = CalibrationMath.reading(of: merge, headroom: sweepHeadroom ?? 1)
        state = .swept(mergeFactor: merge, needsConfirmation: reading == .linearCandidate)
        journal("calibration.swept", values: ["merge": merge ?? 0])
    }

    // MARK: Step 3

    /// Shows the patches for 2 s at the linear-domain Peak factor (0.97 × H), only after a merge near the linear
    /// prediction; only a "distinguishable" answer after it can record `.linear`.
    public func showLinearConfirmation() {
        guard case .swept(let merge, true) = state else { return }
        guard let reading = freshReading(reference: sweepHeadroom) else { return }
        let factor = CalibrationMath.linearConfirmationFactor(headroom: reading.current)
        guard write(factor, maxFactor: factor) else { return }
        state = .confirming
        confirmationShown = true
        journal("calibration.confirmation", values: ["factor": factor])
        generation &+= 1
        let g = generation
        work?.cancel()
        let end = time.now + CalibrationMath.confirmationDuration
        work = Task { [weak self] in
            guard let self else { return }
            while self.time.now < end {
                let left = end - self.time.now
                guard await self.sleep(min(left, CalibrationMath.sweepInterval), generation: g),
                      self.freshReading(reference: self.sweepHeadroom) != nil else { return }
            }
            guard g == self.generation, self.write(1, maxFactor: factor) else { return }
            self.state = .swept(mergeFactor: merge, needsConfirmation: true)
        }
    }

    /// The answer to step 3. Ignored unless the frame was shown; ends the frame at once when it is still up.
    public func answerLinearConfirmation(distinguishable: Bool) {
        guard confirmationShown else {
            journal("calibration.answerWithoutFrame")
            return
        }
        if case .confirming = state {
            generation &+= 1
            work?.cancel()
            guard write(1, maxFactor: 1) else { return }
            state = .swept(mergeFactor: mergeFactor, needsConfirmation: true)
        }
        linearConfirmed = distinguishable
        journal("calibration.answered", values: ["distinguishable": distinguishable ? 1 : 0])
    }

    // MARK: Results

    /// A colorimeter reading of SDR white at Standard, or nil; an implausible value is ignored.
    public func setMeasuredSDRWhite(nits: Double?) {
        guard let nits else { measuredSDRWhite = nil; return }
        guard nits.isFinite, CalibrationMath.plausibleSDRWhite.contains(nits) else { return }
        measuredSDRWhite = nits
    }

    /// Ends the session (Standard at once) and returns the record: `.notBrighter` when the screen did not get brighter,
    /// else the decision rule; nil when nothing was measured. A second call returns the same record.
    public func finish(brighter: Bool?) -> CalibrationRecord? {
        if case .finished = state { return record }
        end()
        state = .finished
        guard brighter != nil || sweepRan || measuredSDRWhite != nil else { return nil }
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

    /// Stops every task, returns the display to Standard and calls `onEnd`, once.
    private func end() {
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
        let callback = onEnd
        onEnd = nil
        callback?()
    }

    /// One factor through the driver; a refusal ends the session.
    private func write(_ factor: Double, maxFactor: Double) -> Bool {
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
    private func freshReading(reference: Double?) -> HeadroomReading? {
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
    private func sleep(_ duration: Duration, generation g: UInt64) async -> Bool {
        do { try await time.sleep(for: duration) } catch { return false }
        return g == generation && !ended
    }

    private func journal(_ code: String, values: [String: Double] = [:]) {
        writer.journal.record(JournalEvent(seconds: time.now.sinceOrigin.timeInterval,
                                           category: LogCategory.engine.rawValue, display: display.rawValue,
                                           code: code, values: values))
    }
}
