// OverbrightBoostTests/Fakes/GuardingReducer.swift — TestSupport's reference reducer plus the few guards the engine
// tests need (battery, Low Power, heat, schedule, Focus on). ARCHITECTURE.md §6.1 rows 9–13 (boost-only guards),
// §5.4 (thermal serious caps at ×1.2). Not a specification of the real reducer; WP1 owns that.
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport

/// Applies `base`, then stops the boost half (dimming passes) for battery below the threshold, Low Power Mode,
/// thermal critical and outside the schedule, and caps it at ×1.2 when thermal is serious.
struct GuardingReducer {
    var base = ReferenceReducer()

    func decide(_ input: PolicyInput) -> PolicyDecision {
        var decision = base.decide(input)
        guard input.isMasterOn else { return decision }
        let power = input.system.power
        var stop: LimitReason?
        if input.system.thermal == .critical {
            stop = .thermalCritical
        } else if power.isLowPowerMode, input.settings.pauseInLowPowerMode {
            stop = .lowPowerMode
        } else if power.source == .battery, let percent = power.batteryPercent,
                  percent < input.settings.batteryThreshold {
            stop = .battery(percent: percent, threshold: input.settings.batteryThreshold)
        } else if let schedule = input.settings.schedule, !schedule.contains(minuteOfDay: input.minuteOfDay) {
            stop = .outsideSchedule
        }
        for (key, display) in decision.displays {
            guard case .boost(let gain) = display.target else { continue }
            var changed = display
            if let stop {
                changed.target = .neutral
                changed.reasons = [stop]
            } else if input.system.thermal == .serious, gain > GainCeiling.thermalSeriousGain {
                changed.target = .boost(gain: GainCeiling.thermalSeriousGain)
                changed.reasons = [.thermalSerious]
            }
            decision.displays[key] = changed
        }
        return decision
    }
}
