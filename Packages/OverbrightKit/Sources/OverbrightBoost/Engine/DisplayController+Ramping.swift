// OverbrightBoost/Engine/DisplayController+Ramping.swift — ramps, user and recovery raises, poll bursts and the
// safety drop. ARCHITECTURE.md §4.3 (ramping and boosted rows), §5.4 (`liveCap` at write time), §5.7 (ramps), §5.8
// (rate limiter, oscillation detector), D5. MainActor; every step carries the generation and the epoch stamp.
import Foundation
import OverbrightCore
import OverbrightPolicy

extension DisplayController {
    /// Why a poll burst runs (§4.4 `pollBurst`: 10 Hz for at most 3 s).
    enum BurstPurpose: Hashable, Sendable {
        /// A raise the user asked for waits for more headroom: raise further as it arrives.
        case raise
        /// Headroom recovered by itself: raise once it has been stable for 1.5 s and the target is ≥ 5 % higher.
        case recovery
        /// A pre-held arm whose other source may have left: escalate after 2.5 s below the needed headroom.
        case heldSource
    }

    // MARK: Ramps

    /// Starts a ramp from the applied gain to `gain` (after the rate limiter's delay for an opposing transition).
    /// - Parameters:
    ///   - finalPhase: the phase when the ramp ends (nil keeps the phase: the dim factor returning to 1 while arming).
    ///   - removesWindowsAtEnd: remove the trigger and overlay once the table is at or below the baseline.
    ///   - rateLimited: false for Back to Standard and the ramped stop, which never wait (they always work, §4.9).
    func startRamp(to gain: Double, kind: RampPlanner.Kind? = nil, origin: Origin, finalPhase: EnginePhase?,
                   removesWindowsAtEnd: Bool = false, setsRampingPhase: Bool = true, rateLimited: Bool = true) {
        rampSerial &+= 1
        let serial = rampSerial
        let stamp = generation
        let kind = kind ?? rampKind
        let direction: FlickerGuard.Direction = gain >= appliedGain ? .up : .down
        let delay = rateLimited ? flicker.delay(before: direction, at: deps.time.now) : .zero
        if setsRampingPhase, phase != .disarming { phase = .ramping }
        rampSlot.run { [weak self] in
            guard let self else { return }
            if delay > .zero {
                guard await self.sleep(delay, stamp), self.rampSerial == serial else { return }
            }
            await self.runRamp(to: gain, kind: kind, origin: origin, finalPhase: finalPhase,
                               removesWindowsAtEnd: removesWindowsAtEnd, serial: serial, stamp: stamp)
        }
    }

    /// The ramp itself: ≥ 6 writes, smoothstep in stops, the last one exactly at the target (§5.7).
    func runRamp(to gain: Double, kind: RampPlanner.Kind, origin: Origin, finalPhase: EnginePhase?,
                 removesWindowsAtEnd: Bool, serial: UInt64, stamp: UInt64) async {
        let start = appliedGain
        if abs(gain - start) > 1e-9 {
            let direction: FlickerGuard.Direction = gain > start ? .up : .down
            if flicker.record(direction, at: deps.time.now, origin: origin) {
                fail(.oscillation)
                return
            }
            let plan = RampPlanner.plan(from: start, to: gain, kind: kind)
            for step in plan.gains {
                guard await sleep(plan.interval, stamp), rampSerial == serial else { return }
                guard writeGain(step) else { break }
            }
        }
        guard isCurrent(stamp), rampSerial == serial else { return }
        if removesWindowsAtEnd, appliedGain <= 1 + TableWriter.neutralTolerance { removeWindows() }
        if let finalPhase { phase = finalPhase }
        settled()
    }

    /// After a ramp ends: the drift watch runs while boosted or dimmed; idle does no work at all.
    func settled() {
        switch phase {
        case .boosted, .dimmed:
            if !driftSlot.isRunning { startDriftWatch() }
        case .idle:
            driftSlot.cancel(); burstSlot.cancel(); checkSlot.cancel(); rebaseSlot.cancel()
            if switchesMechanism {
                switchesMechanism = false
                mechanism = decision?.mechanism ?? mechanism
                notify(needsReduction: true)
                return
            }
        default:
            break
        }
        notify()
    }

    /// One write of light gain `gain` through `TableWriter` (or the overlay). False when nothing was written; a
    /// refusal by a stale epoch starts the hang recovery, any other refusal lands on the baseline at once.
    func writeGain(_ gain: Double) -> Bool {
        guard !isOffConsole, parameters.isSessionActive else { return false }
        if mechanism == .overlay { return setOverlayGain(gain) }
        guard let baseline else { return false }
        let reading = gain > 1 + TableWriter.neutralTolerance ? takeReading() : nil
        do {
            let outcome = try deps.writer.write(writeRequest(gain, baseline: baseline), to: ref, reading: reading,
                                                epoch: epochStamp)
            appliedGain = outcome.appliedGain
            appliedFactor = outcome.factor
            appliedLimit = outcome.limit
            if let reading { flicker.noteHeadroom(reading.current) }
            return true
        } catch GammaError.writeRefused {
            if epochStamp != deps.ledger.hangEpoch {
                recoverFromHang()
            } else {
                writeBaselineNow()
            }
            return false
        } catch {
            deps.journal.record("write.failed", display: key, time: deps.time, category: .gamma)
            return false
        }
    }

    /// The overlay's factor for light gain `gain`, capped by the same interlock (`TableWriter.allowedGain`).
    func setOverlayGain(_ gain: Double) -> Bool {
        guard let overlay else { return false }
        var applied = gain
        if gain > 1 + TableWriter.neutralTolerance {
            let request = writeRequest(gain, baseline: .identity(count: 2))
            applied = (try? deps.writer.allowedGain(for: request, on: ref, reading: takeReading()).appliedGain) ?? 1
        }
        // Exactly 1 at Standard: `tableFactor(1)` is 0.999…, which would end the overlay's EDR request.
        let factor = applied >= 1 - TableWriter.neutralTolerance && applied <= 1 + TableWriter.neutralTolerance
            ? 1 : FactorMath.tableFactor(forLightGain: applied, domain: domain)
        do {
            try overlay.setFactor(factor, headroomRequest: overlayRequest)
        } catch {
            deps.journal.record("overlay.failed", display: key, time: deps.time, category: .trigger)
            return false
        }
        appliedGain = applied
        appliedFactor = factor
        return true
    }

    /// The gain the interlock allows for `gain` with a reading taken now (nil without a reading or a baseline).
    func allowedGain(for gain: Double) -> Double? {
        guard let baseline = baseline ?? (mechanism == .overlay ? .identity(count: 2) : nil) else { return nil }
        let reading = takeReading()
        return try? deps.writer.allowedGain(for: writeRequest(gain, baseline: baseline), on: ref, reading: reading)
            .appliedGain
    }

    // MARK: Raises and lowerings while boosted

    /// A new boost target while ramping or boosted: lower with a ramp; raise at once as far as a reading taken now
    /// allows, then follow arriving headroom with a poll burst (§4.3, §5.7).
    func adjustBoost(_ gain: Double, requested: Bool) {
        let origin: Origin = requested ? .user : .automatic
        let current = appliedGain
        if gain < current - 1e-6 {
            burstSlot.cancel()
            startRamp(to: gain, origin: origin, finalPhase: .boosted)
            return
        }
        guard let allowed = allowedGain(for: gain) else { return }
        if abs(allowed - current) > 1e-6 { startRamp(to: allowed, origin: origin, finalPhase: .boosted) }
        if allowed < gain - 1e-6 { startBurst(.raise) }
    }

    /// The safety drop (§4.3): one write at once to `0.97 × H` (the baseline when H < 1.03), never rate-limited;
    /// counted by the oscillation detector unless the headroom readings moved monotonically.
    func lowerForSafety() {
        let before = appliedGain
        rampSerial &+= 1
        rampSlot.cancel()
        guard writeGain(appliedGain) else { return }
        deps.journal.record("interlock.lowered", display: key,
                            values: ["before": before, "after": appliedGain, "headroom": lastReading?.current ?? 0],
                            time: deps.time)
        if flicker.record(.down, at: deps.time.now, origin: .headroomTracking) {
            fail(.oscillation)
            return
        }
        if phase == .ramping { phase = .boosted }
        settled()
    }

    /// The headroom check of the drift tick and of screen-parameter events: the safety drop, the pre-held watch and the
    /// headroom-recovery raise.
    func headroomCheck() {
        guard phase == .boosted, let reading = takeReading() else { return }
        let headroom = reading.current
        flicker.noteHeadroom(headroom)
        if appliedGain > 1, appliedGain > FactorMath.lowerThreshold * headroom { lowerForSafety() }
        guard phase == .boosted, let gain = targetGain else { return }
        if armedPreHeld, !heldSourceCheck(headroom) {
            startBurst(.heldSource)
            return
        }
        guard gain >= appliedGain * EngineTiming.raiseHysteresis - 1e-9, let allowed = allowedGain(for: gain),
              allowed >= appliedGain * EngineTiming.raiseHysteresis - 1e-9 else { return }
        startBurst(.recovery)
    }

    /// The pre-held watch: false while the display waits below the needed headroom after the other source left;
    /// escalates after `rungTimeout` of that (§4.3 "boosted (armed pre-held)").
    func heldSourceCheck(_ headroom: Double) -> Bool {
        guard armedPreHeld, let gain = targetGain else {
            belowNeededSince = nil
            return true
        }
        let needed = gain / FactorMath.headroomMargin
        let dropped = headroom < (preHeldHeadroom ?? headroom) - EngineTiming.movementThreshold
        guard headroom < needed - 1e-9, dropped else {
            belowNeededSince = nil
            return true
        }
        let now = deps.time.now
        guard let since = belowNeededSince else {
            belowNeededSince = now
            return false
        }
        if now - since >= EngineTiming.rungTimeout {
            escalateAfterHeldSourceLeft(headroom: headroom)
            return true
        }
        return false
    }

    // MARK: Poll bursts

    /// Starts a 10 Hz poll burst of at most 3 s (a user raise replaces a running burst).
    func startBurst(_ purpose: BurstPurpose) {
        if burstSlot.isRunning, purpose != .raise { return }
        let stamp = generation
        burstSlot.run { [weak self] in await self?.runBurst(purpose, stamp) }
    }

    func runBurst(_ purpose: BurstPurpose, _ stamp: UInt64) async {
        let started = deps.time.now
        var stable: [GateEvaluator.Sample] = []
        while deps.time.now - started < EngineTiming.pollBurstLimit {
            guard await sleep(EngineTiming.pollBurstInterval, stamp) else { return }
            guard phase == .boosted || phase == .ramping, let gain = targetGain, let reading = takeReading() else { return }
            let headroom = reading.current
            let now = deps.time.now
            flicker.noteHeadroom(headroom)
            if appliedGain > 1, appliedGain > FactorMath.lowerThreshold * headroom {
                lowerForSafety()
                continue
            }
            switch purpose {
            case .raise:
                guard !rampSlot.isRunning, let allowed = allowedGain(for: gain) else { continue }
                if allowed > appliedGain + 1e-6 { startRamp(to: allowed, origin: .user, finalPhase: .boosted) }
                if allowed >= gain - 1e-6 { return }
            case .recovery:
                stable.append(GateEvaluator.Sample(time: now, headroom: headroom))
                guard GateEvaluator.isStable(stable, now: now), !rampSlot.isRunning,
                      let allowed = allowedGain(for: gain),
                      allowed >= appliedGain * EngineTiming.raiseHysteresis - 1e-9 else { continue }
                startRamp(to: allowed, origin: .headroomTracking, finalPhase: .boosted)
                return
            case .heldSource:
                if heldSourceCheck(headroom) { return }
            }
        }
    }
}
