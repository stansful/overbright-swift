// OverbrightCore/Model/Policy/DisplayDecision.swift — the reducer's decision for one display. ARCHITECTURE.md §3.4, §6.1.

/// The reducer's decision for one display.
public nonisolated struct DisplayDecision: Hashable, Sendable {
    /// The display.
    public var key: DisplayKey
    /// What it should show.
    public var target: BoostTarget
    /// Why it is not at the user's level, in precedence order (the first is the chip).
    public var reasons: [LimitReason]
    /// Verdict, advisories and class defaults.
    public var eligibility: EligibilityResult
    /// Effective transfer domain (a stale or unconfirmed calibration falls back to `.encoded`, §5.2).
    public var domain: TransferDomain
    /// Light gain the user's level asks for before any cap (for the readout and the "limited" chip).
    public var requestedGain: Double
    /// The level the reducer used: the display's own, the linked level, or the Focus filter's (§6.1 step 3). The
    /// readout names the preset at this level (`Readout.values`); `DisplayStatus` carries no level of its own.
    public var level: LevelPosition
    /// A decision.
    public init(key: DisplayKey, target: BoostTarget, reasons: [LimitReason], eligibility: EligibilityResult,
                domain: TransferDomain, requestedGain: Double, level: LevelPosition = .standard) {
        self.key = key; self.target = target; self.reasons = reasons; self.eligibility = eligibility
        self.domain = domain; self.requestedGain = requestedGain; self.level = level
    }
}
