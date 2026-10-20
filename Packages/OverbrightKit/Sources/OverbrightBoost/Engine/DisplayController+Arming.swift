// OverbrightBoost/Engine/DisplayController+Arming.swift — starting an arm: idle headroom, the pre-held test and the
// ladder's rungs (make before break). ARCHITECTURE.md §4.3 (idle → arming/gating, arming rows), §4.7 (ladder, cache),
// D6. MainActor.
import Foundation
import OverbrightCore
import OverbrightPolicy

extension DisplayController {
    /// Potential at or below `1 + this` means "no EDR at all": stop escalating (§4.3).
    static let potentialEpsilon = 0.01
    /// Gate samples kept (≥ the stability window at 10 Hz).
    static let maximumSamples = 64

    // MARK: Starting an arm

    /// idle or dimmed → boost: capture the baseline (from idle), read H0, decide the path, show the first rung, gate.
    /// A table that cannot be read leaves the display idle for the next reduction to retry (`couldNotStart`); our own
    /// write still on screen (a failed landing) is never captured as a baseline.
    func beginArm() {
        generation += 1
        let stamp = generation
        armSlot.cancel(); burstSlot.cancel(); driftSlot.cancel(); lingerSlot.cancel()
        if phase == .idle, !isScaledOrDimmed, !lastWriteIsScaled {
            guard captureBaseline() else {
                if !phase.isFailed { couldNotStart() }
                return
            }
        }
        if appliedGain < 1 - TableWriter.neutralTolerance {
            // The dim factor ramps back to 1 while arming (§4.3 dimmed → boost).
            startRamp(to: 1, origin: .automatic, finalPhase: nil, setsRampingPhase: false)
        } else {
            rampSlot.cancel()
        }
        backoff = nil
        pendingResume = nil
        rungs = plannedRungs(backoff: false)
        currentRung = nil
        phase = .arming(rung: rungs.first?.number ?? 0)
        armSlot.run { [weak self] in await self?.runArm(stamp) }
    }

    /// H0 (three reads 100 ms apart, the maximum), the pre-held test, the first rung, then the gate.
    func runArm(_ stamp: UInt64) async {
        guard let reads = await idleReads(stamp) else { return }
        idleHeadroom = reads.max() ?? 1
        if let potential = lastReading?.potential, potential <= 1 + Self.potentialEpsilon {
            fail(.headroomNeverArrived)
            return
        }
        armedPreHeld = GateEvaluator.isPreHeld(idleReads: reads, gain: targetGain ?? 1,
                                               ownSurface: deps.ownEDRSurfaces.isHeld(key))
        preHeldHeadroom = armedPreHeld ? idleHeadroom : nil
        gatePath = armedPreHeld ? .preHeld : .normal
        cachedRungFailedThisArm = false
        belowNeededSince = nil
        deps.journal.record(armedPreHeld ? "gate.preHeld" : "arm.start", display: key,
                            values: ["h0": idleHeadroom], time: deps.time)
        guard await presentRung(from: 0, stamp) else { return }
        await gateLoop(stamp)
    }

    /// `baselineReads` headroom reads `baselineReadInterval` apart (1.0 without a reading); nil when superseded.
    func idleReads(_ stamp: UInt64) async -> [Double]? {
        var reads: [Double] = []
        for index in 0..<EngineTiming.baselineReads {
            if index > 0 { guard await sleep(EngineTiming.baselineReadInterval, stamp) else { return nil } }
            guard isCurrent(stamp) else { return nil }
            reads.append(takeReading()?.current ?? 1)
        }
        return reads
    }

    /// The rungs of this arm (§4.7): from the cached rung, the override, OLED black only, the backoff's single rung.
    func plannedRungs(backoff: Bool) -> [LadderRung] {
        let cached = deps.cache.record(for: key, osBuild: deps.machine.osBuild)?.rung
        let available = Set(TriggerStrategy.allCases.filter { deps.triggers.isAvailable($0) })
        return LadderPlanner.rungs(for: facts, isOLED: parameters.isOLED, os: deps.machine.osMajor, cache: cached,
                                   override: parameters.triggerOverride, backoff: backoff, available: available)
    }

    // MARK: Rungs (§4.7)

    /// Shows the first rung from `position` that presents (make before break); in a wake or unlock backoff the same
    /// rung is retried after each backoff step instead of escalating. False (and failed) when nothing presents.
    func presentRung(from position: Int, _ stamp: UInt64) async -> Bool {
        var position = position
        while position < rungs.count {
            let rung = rungs[position]
            if await present(rung, stamp) {
                rungPosition = position
                currentRung = rung
                if position > 0 {
                    deps.journal.record("rung.escalated", display: key, values: ["rung": Double(rung.number)],
                                        time: deps.time, category: .trigger)
                }
                restartGate()
                return true
            }
            guard isCurrent(stamp) else { return false }
            deps.journal.record("rung.presentFailed", display: key, values: ["rung": Double(rung.number)],
                                time: deps.time, category: .trigger)
            noteRungFailure(rung)
            if let current = backoff {
                guard current.step < EngineTiming.wakeBackoff.count else { break }
                backoff = (current.kind, current.step + 1)
                guard await sleep(EngineTiming.wakeBackoff[current.step], stamp) else { return false }
                continue
            }
            position += 1
        }
        guard isCurrent(stamp) else { return false }
        fail(.headroomNeverArrived)
        return false
    }

    /// Makes and presents one rung; on success it replaces the previous trigger, which is removed only now.
    func present(_ rung: LadderRung, _ stamp: UInt64) async -> Bool {
        let request = LadderPlanner.request(for: rung, facts: facts, potential: lastReading?.potential ?? 1)
        let handle: any TriggerHandle
        do {
            handle = try deps.triggers.makeTrigger(request, on: ref)
        } catch {
            return false
        }
        handle.onOcclusionChange = { [weak self, weak handle] occluded in
            guard let self, let handle else { return }
            self.windowOcclusionChanged(occluded, isCurrentWindow: handle === self.trigger)
        }
        handle.onScreenChange = { [weak self, weak handle] displayID in
            guard let self, let handle else { return }
            self.windowMoved(to: displayID, isCurrentWindow: handle === self.trigger)
        }
        let presented = await handle.present(rung.pixel)
        guard presented, isCurrent(stamp) else {
            handle.remove()
            return false
        }
        let previous = trigger
        trigger = handle
        previous?.remove()
        return true
    }

    /// A fresh gate on the current rung: the rung timeout restarts, samples are dropped.
    func restartGate() {
        let now = deps.time.now
        presentedAt = now
        movedAt = gatePath == .preHeld ? now : nil
        gatePause = .zero
        samples = []
        let number = currentRung?.number ?? 0
        phase = gatePath == .preHeld ? .gating(rung: number) : .arming(rung: number)
    }

    /// Counts a failure of the cached rung once per normal arm, outside the wake/unlock quarantine (§4.7).
    func noteRungFailure(_ rung: LadderRung) {
        guard !armedPreHeld, !cachedRungFailedThisArm else { return }
        let quarantined = quarantineUntil.map { deps.time.now < $0 } ?? false
        guard deps.cache.record(for: key, osBuild: deps.machine.osBuild)?.rung == rung.number else { return }
        cachedRungFailedThisArm = true
        deps.cache.recordFailure(rung: rung.number, for: key, osBuild: deps.machine.osBuild, quarantined: quarantined)
    }

}
