// OverbrightPolicy/Reducer/BannerSelector.swift — the one "Paused because…" banner. ARCHITECTURE.md §6.3;
// DESIGN.md §5.8, §12.3.
import Foundation
import OverbrightCore

/// Chooses at most one banner among the reasons that stop at least one display that would otherwise change:
/// `userPaused` > `conflict` (S1/S2) > `foreignTableAtLaunch` > `flickerStop` / `unattributedDrift` > `attributedDrift`
/// > `focusOff` > `thermalCritical` > `lowPowerMode` > `battery` > `onBattery` > `outsideSchedule`. Ties go to the
/// first display in input order. A user pause shows whatever the levels are (it is a state the user set), and a
/// foreign table at launch whatever the display's level (its colours are wrong either way).
nonisolated enum BannerSelector {
    static func banner(for outcomes: [DisplayOutcome], input: PolicyInput) -> Banner? {
        guard input.isMasterOn else { return nil }
        if let until = input.pausedUntil, until > input.now { return .userPaused(until: until) }   // the top rank
        var best: (rank: Int, banner: Banner)?
        for outcome in outcomes {
            for reason in outcome.decision.reasons {
                guard let candidate = banner(for: reason, display: outcome.decision.key, input: input),
                      outcome.requestsChange || showsAtAnyLevel(candidate.banner) else { continue }
                if best.map({ candidate.rank < $0.rank }) ?? true { best = candidate }
            }
        }
        return best?.banner
    }

    /// Attention banners: the menu bar symbol shows `attention` while one of them is up (§6.4).
    static func isAttention(_ banner: Banner) -> Bool {
        switch banner {
        case .conflict, .foreignTableAtLaunch, .flickerStop, .unattributedDrift, .attributedDrift: true
        case .userPaused, .focusOff, .thermalCritical, .lowPowerMode, .battery, .onBattery, .outsideSchedule: false
        }
    }

    private static func showsAtAnyLevel(_ banner: Banner) -> Bool {
        switch banner {
        case .userPaused, .foreignTableAtLaunch: true
        default: false
        }
    }

    /// The banner a reason raises on `display`, with its precedence rank (lower wins); nil for per-display reasons.
    private static func banner(for reason: LimitReason, display: DisplayKey,
                               input: PolicyInput) -> (rank: Int, banner: Banner)? {
        let banner: Banner
        switch reason {
        case .userPaused(let until): banner = .userPaused(until: until)
        case .conflict(let app) where reason.isGlobal: banner = .conflict(app)
        case .tripped(.foreignTableAtLaunch): banner = .foreignTableAtLaunch
        case .tripped(.oscillation): banner = .flickerStop(display: display)
        case .tripped(.repairBudgetExceeded): banner = .unattributedDrift(display: display)
        case .tripped(.attributedDrift(let app)): banner = .attributedDrift(app, display: display)
        case .focusOff: banner = .focusOff
        case .thermalCritical: banner = .thermalCritical
        case .lowPowerMode: banner = .lowPowerMode
        case .battery(let percent, let threshold): banner = .battery(percent: percent, threshold: threshold)
        case .onBattery: banner = .onBattery
        case .outsideSchedule:
            guard let schedule = input.settings.schedule else { return nil }
            banner = .outsideSchedule(schedule)
        default: return nil
        }
        return (rank(of: banner), banner)
    }

    private static func rank(of banner: Banner) -> Int {
        switch banner {
        case .userPaused: 0
        case .conflict: 1
        case .foreignTableAtLaunch: 2
        case .flickerStop, .unattributedDrift: 3
        case .attributedDrift: 4
        case .focusOff: 5
        case .thermalCritical: 6
        case .lowPowerMode: 7
        case .battery: 8
        case .onBattery: 9
        case .outsideSchedule: 10
        }
    }
}
