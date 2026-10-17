// OverbrightBoost/Engine/DisplayController+Decisions.swift — the reducer's decision for one display: boost, dim or
// neutral from every phase. ARCHITECTURE.md §4.3 (the target rows), §4.9, §5.7, §5.8. MainActor.
import Foundation
import OverbrightCore
import OverbrightPolicy

extension DisplayController {
    /// Applies the reducer's decision for this display. `requested` marks a change the user asked for (slider,
    /// preset, step, intent, Focus): it raises at once and never counts towards the oscillation detector. A display
    /// at rest whose last landing failed writes its baseline again first.
    func update(_ decision: DisplayDecision, parameters: WriteParameters, requested: Bool) {
        let parametersChanged = parameters != self.parameters
        self.decision = decision
        self.parameters = parameters
        domain = decision.domain
        let changed = !Self.sameTarget(decision.target, target)
        target = decision.target
        guard !isOffConsole, parameters.isSessionActive, !isDriven else { return }
        retryLandingAtRest()
        if decision.mechanism != mechanism {
            guard isActive || isScaledOrDimmed else {
                mechanism = decision.mechanism
                return update(decision, parameters: parameters, requested: requested)
            }
            // Switch mechanisms through neutral: disarm, then the next reduction arms the other one.
            switchesMechanism = true
            disarm(kind: rampKind)
            return
        }
        switch phase {
        case .failed:
            return
        case .suspended(let cause):
            resumeIfPossible(cause, requested: requested)
            return
        case .disarming:
            if case .neutral = target { return }
        default:
            break
        }
        if !changed {
            if parametersChanged, case .boost(let gain) = target, phase == .boosted {
                followParameters(gain, requested: requested)
            }
            return
        }
        switch target {
        case .neutral: disarm(kind: rampKind)
        case .dim(let light): goDim(light, origin: requested ? .user : .automatic)
        case .boost(let gain): goBoost(gain, requested: requested)
        }
    }

    /// The ramp duration for policy and user changes now (Reduce Motion shortens it, never to a snap).
    var rampKind: RampPlanner.Kind { parameters.reduceMotion ? .reduceMotion : .standard }

    /// The same boost target, but what the interlock allows moved with the write parameters (cap mode, the SDR-white
    /// estimate, HDR suppression ending). A user's request raises at once (§4.3 user-raise row); anything else lowers
    /// with a ramp, or raises only through the headroom-recovery path (≥ 1.05 × applied, 1.5 s stable, counted by the
    /// oscillation detector, §5.7, §5.8).
    func followParameters(_ gain: Double, requested: Bool) {
        if requested {
            adjustBoost(gain, requested: true)
            return
        }
        guard let allowed = allowedGain(for: gain) else { return }
        if allowed < appliedGain - 1e-6 {
            burstSlot.cancel()
            startRamp(to: allowed, origin: .automatic, finalPhase: .boosted)
        } else if allowed >= appliedGain * EngineTiming.raiseHysteresis - 1e-9 {
            startBurst(.recovery)
        }
    }

    /// The arm or dim could not start (the table could not be read, the overlay could not be made): the display stays
    /// idle and forgets the target, so the next reduction tries again instead of waiting for the target to change.
    func couldNotStart() {
        target = .neutral
        deps.journal.record("arm.couldNotStart", display: key, time: deps.time)
    }

    func goBoost(_ gain: Double, requested: Bool) {
        switch phase {
        case .idle, .dimmed:
            beginArm()
        case .arming, .gating, .suspended, .failed:
            break
        case .disarming:
            if trigger != nil || overlay != nil, appliedGain >= 1 {
                rampSerial &+= 1                                      // the disarm ramp stops where it is
                rampSlot.cancel()
                phase = .boosted
                adjustBoost(gain, requested: true)
                // The disarm cancelled the drift watch. A rate-limited disarm that wrote no step yet leaves the applied
                // gain where the boost wants it, so no ramp starts and none would end in `settled()`: settle here, or
                // the display stays boosted with no drift check and no headroom check.
                if !rampSlot.isRunning { settled() }
            } else {
                beginArm()
            }
        case .ramping, .boosted:
            if trigger == nil && overlay == nil { beginArm() } else { adjustBoost(gain, requested: requested) }
        }
    }

    func goDim(_ light: Double, origin: Origin) {
        switch phase {
        case .idle:
            generation += 1
            if mechanism == .overlay {
                guard ensureOverlay() else { return couldNotStart() }
            } else if !isScaledOrDimmed, !lastWriteIsScaled {           // never capture our own write still on screen
                guard captureBaseline() else {
                    if !phase.isFailed { couldNotStart() }
                    return
                }
            }
            epochStamp = deps.ledger.hangEpoch
            startRamp(to: light, origin: origin, finalPhase: .dimmed)
        case .dimmed:
            startRamp(to: light, origin: origin, finalPhase: .dimmed)
        case .arming, .gating:
            generation += 1
            armSlot.cancel(); burstSlot.cancel()
            removeTrigger()
            startRamp(to: light, origin: origin, finalPhase: .dimmed, removesWindowsAtEnd: true)
        case .ramping, .boosted, .disarming:
            generation += 1
            armSlot.cancel(); burstSlot.cancel(); driftSlot.cancel()
            startRamp(to: light, origin: origin, finalPhase: .dimmed, removesWindowsAtEnd: true)
        case .suspended, .failed:
            break
        }
    }

    /// Ramp to 1 → baseline → remove the trigger (§4.5 invariant 2) → idle. The quit's stop is not rate-limited. With
    /// nothing applied there is no ramp, but a table that may be off its baseline (`tableMayBeOffBaseline`) gets the
    /// baseline before the windows go; a refused write is retried at rest by the reduction it asks for, and while the
    /// ledger marks the display the trigger waits for that retry (`landUnscaled`).
    func disarm(kind: RampPlanner.Kind, rateLimited: Bool = true) {
        switch phase {
        case .idle, .failed:
            return
        case .suspended:
            generation += 1
            cancelAllTasks()
            landAndGoIdle(kind: kind, rateLimited: rateLimited)
        default:
            generation += 1
            armSlot.cancel(); burstSlot.cancel(); driftSlot.cancel(); lingerSlot.cancel()
            guard isScaledOrDimmed else {
                rampSlot.cancel()
                if !landUnscaled() { notify(needsReduction: true) }
                phase = .idle
                return
            }
            phase = .disarming
            startRamp(to: 1, kind: kind, origin: .automatic, finalPhase: .idle, removesWindowsAtEnd: true,
                      setsRampingPhase: false, rateLimited: rateLimited)
        }
    }
}
