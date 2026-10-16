// OverbrightBoost/Engine/DisplayController+Support.swift — trips and the helpers every part of the controller uses (readings,
// generations, the baseline write, window removal, journal codes). ARCHITECTURE.md §4.3, §4.5 invariants 2, 4 and 7,
// §4.6. MainActor.
import Foundation
import OverbrightCore
import OverbrightPolicy
import os

private let log = Log.logger(.engine)

extension DisplayController {
    // MARK: Trips

    /// Lands on neutral at once (one write), removes every window and records `cause` as the feedback. While
    /// WindowServer refuses that landing and our scaled table is still on screen, the trigger stays with it (§4.5
    /// invariant 2) until a later landing succeeds (`retryLandingAtRest`, Back to Standard, a stop).
    func fail(_ cause: TripCause) {
        generation += 1
        cancelAllTasks()
        if !writeBaselineNow(), keepsWindowsAfterFailedLanding {
            deps.journal.record("order.windowsKept", display: key, time: deps.time, category: .gamma)
        } else {
            removeWindows()
        }
        if case .headroomNeverArrived = cause {
            failedTries += 1
            potentialAtFailure = lastReading?.potential
        }
        trip = cause
        deps.journal.record(Self.tripCode(cause), display: key, time: deps.time)
        log.info("display failed: \(Self.tripCode(cause), privacy: .public)")
        phase = .failed(cause)
        notify(needsReduction: true)
    }

    /// Try Again (and the automatic retries of §4.3): clears the trip; the next reduction re-arms.
    func clearTrip() {
        guard trip != nil || phase.isFailed else { return }
        generation += 1
        cancelAllTasks()
        trip = nil
        potentialAtFailure = nil
        flicker.reset()
        repairs = []
        unexplainedAdoptions = []
        phase = .idle
        notify(needsReduction: true)
    }

    /// Records a trip found outside the state machine (the launch check's residue).
    func setTrip(_ cause: TripCause) {
        fail(cause)
    }

    // MARK: Shared helpers

    /// A fresh reading of this display (nil without its own NSScreen), kept as `lastReading`.
    @discardableResult
    func takeReading() -> HeadroomReading? {
        let reading = deps.headroom.reading(for: ref)
        if let reading { lastReading = reading }
        return reading
    }

    /// Whether async work stamped with `stamp` is still current (§4.6).
    func isCurrent(_ stamp: UInt64) -> Bool { stamp == generation }

    /// Sleeps on the time source; false when cancelled or superseded.
    func sleep(_ duration: Duration, _ stamp: UInt64) async -> Bool {
        do { try await deps.time.sleep(for: duration) } catch { return false }
        return isCurrent(stamp)
    }

    /// Our latest table write was not the baseline (whatever `appliedFactor` believes after a reset or re-base).
    var lastWriteIsScaled: Bool { abs((lastWrite?.factor ?? 1) - 1) > TableWriter.neutralTolerance }

    /// Our latest table write was above the baseline (it needed the trigger's EDR request).
    var lastWriteIsAboveBase: Bool { (lastWrite?.factor ?? 1) > 1 + TableWriter.neutralTolerance }

    /// After a landing WindowServer refused: the trigger has to stay, because our write above the baseline may still be
    /// on screen (it is, or the table cannot be read). Once WindowServer replaced it (a reset, a new base), the
    /// windows may go.
    var keepsWindowsAfterFailedLanding: Bool {
        guard trigger != nil, mechanism == .table, lastWriteIsAboveBase else { return false }
        return (try? deps.gamma.read(ref.id)).map(isOurs) ?? true
    }

    /// Writes the baseline now when the table (or overlay) is scaled or dimmed, or our latest write was (one write,
    /// never refused by the epoch). True when the display is at its baseline afterwards. When WindowServer (or the
    /// overlay) throws, the applied state is kept, so the display still counts as scaled or dimmed: the ledger keeps its
    /// entry, the trigger stays (see `+WriteFailure`) and the next stop, disarm or reduction writes it again.
    @discardableResult
    func writeBaselineNow() -> Bool {
        guard isScaledOrDimmed || (mechanism == .table && lastWriteIsScaled) else {
            resetApplied()
            return true
        }
        if mechanism == .overlay {
            do {
                try overlay?.setFactor(1, headroomRequest: 1)
            } catch {
                deps.journal.record("overlay.failed", display: key, time: deps.time, category: .trigger)
                return false
            }
            resetApplied()
            return true
        }
        guard let baseline else {
            resetApplied()                                                // nothing to restore with (a rescue forgot it)
            return true
        }
        do {
            try deps.writer.writeBaseline(baseline, to: ref)
        } catch {
            deps.journal.record("baseline.writeFailed", display: key, time: deps.time, category: .gamma)
            log.error("baseline write failed: \(String(describing: error), privacy: .public)")
            return false
        }
        lastWrite = (baseline, 1)
        resetApplied()
        return true
    }

    /// The table (or overlay) is at its baseline.
    func resetApplied() {
        appliedGain = 1
        appliedFactor = 1
        appliedLimit = nil
    }

    /// Orders out the trigger and the overlay (after the table is back at its baseline, §4.5 invariant 2). The safety
    /// net of that order: if our latest write was above the baseline, the baseline is written first, and while
    /// WindowServer refuses it and our scaled table is still on screen both stay (the scaled table keeps its EDR
    /// request); the reduction this asks for retries the landing (`retryLandingAtRest`, as do the linger, Back to
    /// Standard and a stop). `force` removes them anyway, for the two rows that must: the session left the console, or
    /// AppKit moved the window to another display (§4.3).
    func removeWindows(force: Bool = false) {
        if trigger != nil, mechanism == .table, lastWriteIsAboveBase {
            deps.journal.record("order.baselineBeforeRemoval", display: key, time: deps.time)
            if !writeBaselineNow(), !force, keepsWindowsAfterFailedLanding {
                deps.journal.record("order.windowsKept", display: key, time: deps.time, category: .gamma)
                notify(needsReduction: true)
                return
            }
        }
        let windows = (trigger, overlay)
        trigger = nil
        overlay = nil
        windows.0?.remove()
        windows.1?.remove()
        if mechanism == .overlay { resetApplied() }                     // the overlay was the whole effect
        lingerSlot.cancel()
    }

    /// Orders out the trigger only (a dim keeps the Compatibility-mode overlay: it is what dims, §4.3). If our latest
    /// write was above the baseline (a shield or occlusion whose write failed), the baseline is written first; while
    /// WindowServer refuses it and that write is still on screen, the trigger stays (§4.5 invariant 2) and the dim
    /// ramp that follows removes it once the table is at or below the baseline.
    func removeTrigger() {
        guard trigger != nil else { return }
        if mechanism == .table, lastWriteIsAboveBase, !writeBaselineNow(), keepsWindowsAfterFailedLanding {
            deps.journal.record("order.windowsKept", display: key, time: deps.time, category: .gamma)
            return
        }
        let handle = trigger
        trigger = nil
        handle?.remove()
    }

    /// Cancels every task of this controller.
    func cancelAllTasks() {
        rampSerial &+= 1
        isRebasing = false
        for slot in [armSlot, rampSlot, driftSlot, burstSlot, lingerSlot, checkSlot, rebaseSlot] { slot.cancel() }
    }

    /// Ends a running re-base (Back to Standard, idle).
    func stopRebase() {
        rebaseSlot.cancel()
        isRebasing = false
    }

    /// Tells the engine to publish (and, with `needsReduction`, to re-reduce).
    func notify(needsReduction: Bool = false) { onChange?(needsReduction) }

    /// The request the writer needs for `gain`.
    func writeRequest(_ gain: Double, baseline: GammaTable) -> TableWriter.Request {
        TableWriter.Request(gain: gain, domain: domain, baseline: baseline, facts: facts, capMode: parameters.capMode,
                            isOLED: parameters.isOLED, sdrWhite: parameters.sdrWhite, taper: parameters.taper,
                            fullBrightnessHeadroom: fullBrightnessHeadroom)
    }

    /// The taper's reference (§5.4): the lowest ready headroom of this display and OS build, never above the seed
    /// `panelPeak ÷ sdrMax`.
    var fullBrightnessHeadroom: Double? {
        let seed = GainCeiling.fullBrightnessHeadroomSeed(facts: facts)
        let learned = deps.cache.record(for: key, osBuild: deps.machine.osBuild)?.lowestReadyHeadroom
        switch (seed, learned) {
        case let (seed?, learned?): return min(seed, learned)
        case let (seed?, nil): return seed
        case let (nil, learned?): return learned
        case (nil, nil): return nil
        }
    }

    /// Journals and logs every phase change and tells the engine. Reaching idle or failed judges a base event whose
    /// re-base did not finish (§4.8), so the display is never left on the old curve.
    func phaseChanged(from old: EnginePhase) {
        deps.journal.record("phase." + Self.phaseCode(phase), display: key, time: deps.time)
        log.info("phase \(Self.phaseCode(old), privacy: .public) → \(Self.phaseCode(self.phase), privacy: .public)")
        if !isActive { settlePendingRebase() }
        notify()
    }

    static func sameTarget(_ a: BoostTarget, _ b: BoostTarget) -> Bool {
        switch (a, b) {
        case (.neutral, .neutral): true
        case (.dim(let x), .dim(let y)), (.boost(let x), .boost(let y)): abs(x - y) <= 1e-9
        default: false
        }
    }

    static func phaseCode(_ phase: EnginePhase) -> String {
        switch phase {
        case .idle: "idle"
        case .dimmed: "dimmed"
        case .arming: "arming"
        case .gating: "gating"
        case .ramping: "ramping"
        case .boosted: "boosted"
        case .suspended: "suspended"
        case .failed: "failed"
        case .disarming: "disarming"
        }
    }

    static func tripCode(_ cause: TripCause) -> String {
        switch cause {
        case .oscillation: "flicker.trip"
        case .repairBudgetExceeded: "repair.trip"
        case .attributedDrift: "drift.attributedTrip"
        case .headroomNeverArrived: "gate.neverArrived"
        case .foreignTableAtLaunch: "baseline.foreignAtLaunch"
        }
    }
}
