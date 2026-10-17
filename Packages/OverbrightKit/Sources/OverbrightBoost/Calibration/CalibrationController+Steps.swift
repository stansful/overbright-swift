// OverbrightBoost/Calibration/CalibrationController+Steps.swift — the three steps of one calibration: "Does it get
// brighter?", the sweep and the linear confirmation. ARCHITECTURE.md §5.2, §5.6, §5.8; DESIGN.md §9. Thread: main.
// Every factor goes through `write(_:maxFactor:)` (the driver, then `TableWriter`); every async step carries the
// session's generation (§4.6).
import Foundation
import OverbrightCore
import OverbrightPolicy

extension CalibrationController {
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
}
