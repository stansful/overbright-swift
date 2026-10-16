// OverbrightBoost/Engine/DisplayController+Decisions.swift — the reducer's decision for one display: boost, dim or
// neutral from every phase. ARCHITECTURE.md §4.3 (the target rows), §4.9, §5.7. MainActor.
import Foundation
import OverbrightCore
import OverbrightPolicy

extension DisplayController {
    /// Applies the reducer's decision for this display. `requested` marks a change the user asked for (slider,
    /// preset, step, intent, Focus): it raises at once and never counts towards the oscillation detector.
    func update(_ decision: DisplayDecision, parameters: WriteParameters, requested: Bool) {
        let parametersChanged = parameters != self.parameters
        self.decision = decision
        self.parameters = parameters
        domain = decision.domain
        let changed = !Self.sameTarget(decision.target, target)
        target = decision.target
        guard !isOffConsole, parameters.isSessionActive else { return }
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
            if parametersChanged, case .boost(let gain) = target, phase == .boosted { adjustBoost(gain, requested: true) }
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
                guard ensureOverlay() else { return }
            } else {
                guard captureBaseline() else { return }
            }
            epochStamp = deps.ledger.hangEpoch
            startRamp(to: light, origin: origin, finalPhase: .dimmed)
        case .dimmed:
            startRamp(to: light, origin: origin, finalPhase: .dimmed)
        case .arming, .gating:
            generation += 1
            armSlot.cancel(); burstSlot.cancel()
            removeTrigger()
            startRamp(to: light, origin: origin, finalPhase: .dimmed)
        case .ramping, .boosted, .disarming:
            generation += 1
            armSlot.cancel(); burstSlot.cancel(); driftSlot.cancel()
            startRamp(to: light, origin: origin, finalPhase: .dimmed, removesWindowsAtEnd: true)
        case .suspended, .failed:
            break
        }
    }

    /// Ramp to 1 → baseline → remove the trigger (§4.5 invariant 2) → idle. The quit's stop is not rate-limited.
    func disarm(kind: RampPlanner.Kind, rateLimited: Bool = true) {
        switch phase {
        case .idle, .failed:
            return
        case .suspended:
            generation += 1
            cancelAllTasks()
            writeBaselineNow()
            removeWindows()
            phase = .idle
        default:
            generation += 1
            armSlot.cancel(); burstSlot.cancel(); driftSlot.cancel(); lingerSlot.cancel()
            guard isScaledOrDimmed else {
                rampSlot.cancel()
                removeWindows()
                phase = .idle
                return
            }
            phase = .disarming
            startRamp(to: 1, kind: kind, origin: .automatic, finalPhase: .idle, removesWindowsAtEnd: true,
                      setsRampingPhase: false, rateLimited: rateLimited)
        }
    }
}
