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
    /// Table or overlay.
    public var mechanism: Mechanism
    /// Effective transfer domain (a stale or unconfirmed calibration falls back to `.encoded`, §5.2).
    public var domain: TransferDomain
    /// Light gain the user's level asks for before any cap (for the readout and the "limited" chip).
    public var requestedGain: Double
    /// A decision.
    public init(key: DisplayKey, target: BoostTarget, reasons: [LimitReason], eligibility: EligibilityResult,
                mechanism: Mechanism, domain: TransferDomain, requestedGain: Double) {
        self.key = key; self.target = target; self.reasons = reasons; self.eligibility = eligibility
        self.mechanism = mechanism; self.domain = domain; self.requestedGain = requestedGain
    }
}
