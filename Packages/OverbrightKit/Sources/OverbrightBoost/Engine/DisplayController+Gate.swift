// OverbrightBoost/Engine/DisplayController+Gate.swift — the gate loop, rung failures and escalation, readiness, re-gating
// and the pre-held escalation. ARCHITECTURE.md §4.3 (arming, gating, suspended and wake rows), §4.6, §4.7, D6.
// MainActor.
import Foundation
import OverbrightCore
import OverbrightPolicy

extension DisplayController {
    // MARK: The gate (D6)

    /// Polls headroom at 10 Hz until the gate is ready (→ ramp), escalating on rung and gate timeouts.
    func gateLoop(_ stamp: UInt64) async {
        while isCurrent(stamp) {
            guard await sleep(EngineTiming.gatePollInterval, stamp) else { return }
            let now = deps.time.now
            let reading = takeReading()
            let headroom = reading?.current ?? 1
            if let potential = reading?.potential, potential <= 1 + Self.potentialEpsilon {
                fail(.headroomNeverArrived)
                return
            }
            samples.append(GateEvaluator.Sample(time: now, headroom: headroom))
            if samples.count > Self.maximumSamples { samples.removeFirst(samples.count - Self.maximumSamples) }
            flicker.noteHeadroom(headroom)
            if appliedGain > 1, appliedGain > FactorMath.lowerThreshold * headroom { lowerForSafety() }
            if parameters.isHDRSuppressed {
                // Keep the rung and stop escalating: the timeouts pause (§4.3).
                presentedAt = presentedAt.map { $0 + EngineTiming.gatePollInterval }
                if movedAt != nil { gatePause += EngineTiming.gatePollInterval }
            }
            guard let presentedAt else { continue }
            switch GateEvaluator.evaluate(path: gatePath, samples: samples, idle: idleHeadroom,
                                          presentedAt: presentedAt, movedAt: movedAt, gatePause: gatePause, now: now) {
            case .waiting:
                continue
            case .moved:
                movedAt = now
                phase = .gating(rung: currentRung?.number ?? 0)
                deps.journal.record("gate.moved", display: key, values: ["headroom": headroom], time: deps.time)
            case .ready(let ready):
                becomeReady(at: ready)
                return
            case .rungTimedOut, .gateTimedOut:
                guard await rungFailed(stamp) else { return }
            }
        }
    }

    /// A rung or gate timeout: in a backoff, wait and retry the same rung; otherwise escalate (make before break).
    func rungFailed(_ stamp: UInt64) async -> Bool {
        deps.journal.record("rung.timedOut", display: key, values: ["rung": Double(currentRung?.number ?? 0)],
                            time: deps.time, category: .trigger)
        if let rung = currentRung { noteRungFailure(rung) }
        if let current = backoff {
            guard current.step < EngineTiming.wakeBackoff.count else {
                fail(.headroomNeverArrived)
                return false
            }
            backoff = (current.kind, current.step + 1)
            guard await sleep(EngineTiming.wakeBackoff[current.step], stamp) else { return false }
            trigger?.represent()
            overlay?.represent()
            restartGate()
            return true
        }
        guard mechanism == .table else {
            fail(.headroomNeverArrived)
            return false
        }
        return await presentRung(from: rungPosition + 1, stamp)
    }

    /// Ready: cache the rung (normal path only), learn the lowest ready headroom, stamp the epoch, ramp to liveCap.
    func becomeReady(at headroom: Double) {
        deps.journal.record("gate.ready", display: key,
                            values: ["headroom": headroom, "rung": Double(currentRung?.number ?? 0)], time: deps.time)
        if !armedPreHeld, let rung = currentRung {
            deps.cache.recordWin(rung: rung.number, for: key, osBuild: deps.machine.osBuild)
        }
        deps.cache.learnReadyHeadroom(headroom, for: key, osBuild: deps.machine.osBuild)
        backoff = nil
        epochStamp = deps.ledger.hangEpoch
        guard let gain = targetGain else { return }
        startRamp(to: allowedGain(for: gain) ?? 1, origin: .automatic, finalPhase: .boosted)
    }

    // MARK: Re-gating

    /// Re-gates from the cached rung (§4.3 suspended → gating/arming, hang recovery): the kept trigger is re-presented,
    /// else the cached rung is armed; wake and unlock retry that rung only, with backoff. H0 and the path are measured
    /// again first (`remeasureIdle`); a base event the suspension cut short re-bases again.
    func regate(backoff kind: ResumeKind?) {
        generation += 1
        let stamp = generation
        armSlot.cancel(); burstSlot.cancel(); driftSlot.cancel(); lingerSlot.cancel()
        backoff = kind.map { ($0, 0) }
        if kind != nil { quarantineUntil = deps.time.now + EngineTiming.escalationQuarantine }
        let wasPreHeld = armedPreHeld
        let kept = mechanism == .overlay ? overlay != nil : trigger != nil
        armedPreHeld = false
        preHeldHeadroom = nil
        gatePath = .normal
        cachedRungFailedThisArm = false
        belowNeededSince = nil
        restartPendingRebase()
        if mechanism == .overlay {
            overlay?.represent()
            phase = .arming(rung: 0)
            armSlot.run { [weak self] in
                guard let self, await self.remeasureIdle(stamp, wasPreHeld: wasPreHeld, ownWindowKept: kept),
                      self.showOverlay(stamp) else { return }
                await self.gateLoop(stamp)
            }
            return
        }
        if trigger != nil, let rung = currentRung {
            trigger?.represent()
            // The rungs after the kept one in the planned (automatic) order, not by number: the order is 5, 4, 3, 6, 7.
            let planned = plannedRungs(backoff: false)
            let later = planned.firstIndex { $0.number == rung.number }.map { Array(planned[($0 + 1)...]) }
                ?? planned.filter { $0.number != rung.number }
            rungs = backoff != nil ? [rung] : [rung] + later
            rungPosition = 0
            phase = .arming(rung: rung.number)
            armSlot.run { [weak self] in
                guard let self, await self.remeasureIdle(stamp, wasPreHeld: wasPreHeld, ownWindowKept: kept) else {
                    return
                }
                self.restartGate()
                await self.gateLoop(stamp)
            }
        } else {
            rungs = plannedRungs(backoff: backoff != nil)
            phase = .arming(rung: rungs.first?.number ?? 0)
            armSlot.run { [weak self] in
                guard let self, await self.remeasureIdle(stamp, wasPreHeld: wasPreHeld, ownWindowKept: kept),
                      await self.presentRung(from: 0, stamp) else { return }
                await self.gateLoop(stamp)
            }
        }
    }

    /// The re-gate's H0 (D6): three fresh reads decide the path again, so a display another source still holds (an
    /// HDR video across a lock, a sleep or a hang) gates with the absolute rule instead of waiting for movement above
    /// the H0 of its first arm, which never comes. With our own window kept through the suspension the reads may
    /// include our own grant, so only an arm that was pre-held stays pre-held then (an own EDR surface always counts),
    /// and the normal path keeps the lower of the old and the new H0. False when superseded.
    func remeasureIdle(_ stamp: UInt64, wasPreHeld: Bool, ownWindowKept: Bool) async -> Bool {
        guard let reads = await idleReads(stamp) else { return false }
        let fresh = reads.max() ?? 1
        let trusted = wasPreHeld || !ownWindowKept
        let preHeld = deps.ownEDRSurfaces.isHeld(key)
            || (trusted && GateEvaluator.isPreHeld(idleReads: reads, gain: targetGain ?? 1, ownSurface: false))
        armedPreHeld = preHeld
        preHeldHeadroom = preHeld ? fresh : nil
        gatePath = preHeld ? .preHeld : .normal
        idleHeadroom = preHeld || !ownWindowKept ? fresh : min(idleHeadroom, fresh)
        deps.journal.record(preHeld ? "gate.preHeld" : "regate.start", display: key, values: ["h0": idleHeadroom],
                            time: deps.time)
        return true
    }

    /// Boosted on a pre-held arm, and the other source left: escalate from the current rung with H0 := H (§4.3).
    func escalateAfterHeldSourceLeft(headroom: Double) {
        generation += 1
        let stamp = generation
        burstSlot.cancel(); driftSlot.cancel()
        deps.journal.record("gate.heldSourceLeft", display: key, values: ["headroom": headroom], time: deps.time)
        idleHeadroom = headroom
        armedPreHeld = false
        preHeldHeadroom = nil
        gatePath = .normal
        belowNeededSince = nil
        let next = rungPosition + 1
        guard next < rungs.count, mechanism == .table else {
            fail(.headroomNeverArrived)
            return
        }
        phase = .arming(rung: rungs[next].number)
        armSlot.run { [weak self] in
            guard let self, await self.presentRung(from: next, stamp) else { return }
            await self.gateLoop(stamp)
        }
    }
}
