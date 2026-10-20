// OverbrightTestSupport/ReferenceReducer.swift — a tiny, obviously-right reducer for engine tests. ARCHITECTURE.md §9.1,
// §10.1. `BoostEngine` takes its reducer as an injected function (§4.1), so WP4's tests run against this before WP1's
// `BoostPolicy.reduce` exists; it is not a specification of the real reducer's precedence (§6.1).
import Foundation
import OverbrightCore
import OverbrightPolicy

/// The reference reducer: master off, shielded, paused, tripped or a Focus "off" → neutral; a dim level → `.dim`;
/// a boost level with the boost enabled → `.boost(top ^ p)` with a fixed top per display (no eligibility, guards,
/// caps or rules). Use `ReferenceReducer.reduce` for the default top, or `ReferenceReducer(top:tops:).decide`.
public nonisolated struct ReferenceReducer: Sendable {
    /// The M4 Max built-in's Safe top at full brightness: 1000 ÷ 600 nits (§5.3).
    public static let defaultTop = 1000.0 / 600
    /// The top of displays not in `tops`.
    public var top: Double
    /// Tops by display.
    public var tops: [DisplayKey: Double]

    /// A reducer with `top` for every display unless `tops` names it.
    public init(top: Double = defaultTop, tops: [DisplayKey: Double] = [:]) { self.top = top; self.tops = tops }

    /// `ReferenceReducer().decide(input)`: the shape of `BoostEngine`'s injected `reduce`.
    public static func reduce(_ input: PolicyInput) -> PolicyDecision { ReferenceReducer().decide(input) }

    /// The decision for `input`.
    public func decide(_ input: PolicyInput) -> PolicyDecision {
        let isPaused = input.pausedUntil.map { $0 > input.now } ?? false
        var decisions: [DisplayKey: DisplayDecision] = [:]
        for display in input.displays {
            decisions[display.facts.ref.key] = decide(display, in: input, isPaused: isPaused)
        }
        let targets = decisions.values.map(\.target)
        let symbol: StatusSymbolState
        if !input.isMasterOn {
            symbol = .off
        } else if isPaused {
            symbol = .paused
        } else if targets.contains(where: { if case .boost = $0 { true } else { false } }) {
            symbol = .on
        } else if targets.contains(where: { if case .dim = $0 { true } else { false } }) {
            symbol = .dimming
        } else {
            symbol = .on
        }
        let banner: Banner? = if let until = input.pausedUntil, isPaused {
            .userPaused(until: until)
        } else if input.system.focus == .off {
            .focusOff
        } else {
            nil
        }
        return PolicyDecision(displays: decisions, banner: input.isMasterOn ? banner : nil, symbol: symbol)
    }

    private func decide(_ display: DisplayPolicyInput, in input: PolicyInput, isPaused: Bool) -> DisplayDecision {
        let key = display.facts.ref.key
        let top = tops[key] ?? self.top
        let preferences = display.preferences
        var level = input.settings.linkLevels ? input.settings.linkedLevel : preferences.level
        if case .on(let focusLevel) = input.system.focus { level = focusLevel }
        let domain = TransferDomainResolver.effectiveDomain(preferences.calibration, machine: input.machine,
                                                            potential: display.feedback.lastReading?.potential)
        let hasTable = display.facts.gammaCapacity > 0
        let eligibility = EligibilityResult(verdict: hasTable ? .supported(safeGain: top, peakGain: top) : .noGammaTable,
                                            advisories: [], defaultBoostEnabled: true)
        let requested = LevelMapping.requestedGain(for: level, top: top)

        let (target, reasons): (BoostTarget, [LimitReason]) = {
            if !input.isMasterOn { return (.neutral, [.masterOff]) }
            if !hasTable { return (.neutral, [.notSupported(.noGammaTable)]) }
            if input.system.isShielded { return (.neutral, [.shielded]) }
            if isPaused, let until = input.pausedUntil { return (.neutral, [.userPaused(until: until)]) }
            if let trip = display.feedback.trip { return (.neutral, [.tripped(trip)]) }
            if input.system.focus == .off { return (.neutral, [.focusOff]) }
            if level.isDim { return (.dim(light: LevelMapping.dimLight(for: level)), []) }
            guard level.isBoost else { return (.neutral, []) }
            if display.facts.isMirrored { return (.neutral, [.notSupported(.mirrored)]) }
            if !(preferences.boostEnabled ?? true) { return (.neutral, [.boostNotEnabled]) }
            return (.boost(gain: requested), [])
        }()
        return DisplayDecision(key: key, target: target, reasons: reasons, eligibility: eligibility, domain: domain,
                               requestedGain: requested, level: level)
    }
}
