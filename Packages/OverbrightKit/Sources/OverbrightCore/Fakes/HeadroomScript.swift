// OverbrightCore/Fakes/HeadroomScript.swift — how macOS grants headroom on one scripted display. ARCHITECTURE.md §3.9, D6.

/// How macOS answers EDR requests on one display, for `ScriptedHeadroom`: the idle value, the grant a request
/// reaches after a delay and a linear ramp (or never, per strategy), and another source that may already hold EDR
/// (pre-held, D6) and leave at a scripted time. Values follow docs/research/display-facts.md.
public nonisolated struct HeadroomScript: Hashable, Sendable {
    /// H with nothing requesting EDR (1.0, or ≈ 1.2 on macOS 27).
    public var idle: Double
    /// `maximumPotential…` (≈ preset peak ÷ 100 nits); H never exceeds it.
    public var potential: Double
    /// `maximumReference…` (> 0 only in reference presets).
    public var reference: Double
    /// H once a request holds: min(potential, granted peak ÷ SDR white).
    public var grant: Double
    /// From a request's first successful present to the first movement of H.
    public var responseDelay: Duration
    /// From the first movement to `grant` (linear).
    public var rampDuration: Duration
    /// Strategies macOS answers; nil = every strategy, empty = none (headroom never arrives).
    public var respondingStrategies: Set<TriggerStrategy>?
    /// Another source already holds EDR at this H (an HDR video, our own Fill Light) …
    public var preHeld: Double?
    /// … until this long after the script started; nil = it stays.
    public var preHeldLeavesAfter: Duration?
    /// The display has its own NSScreen (false for a hardware-mirror member: no reading at all).
    public var hasOwnScreen: Bool

    /// A script; by default a request is answered after 0.2 s with a 1 s ramp (WindowServer's median up-ramp is
    /// 1.14 s, docs/research/display-facts.md §3).
    public init(idle: Double = 1.0, potential: Double, reference: Double = 0, grant: Double,
                responseDelay: Duration = .milliseconds(200), rampDuration: Duration = .seconds(1),
                respondingStrategies: Set<TriggerStrategy>? = nil, preHeld: Double? = nil,
                preHeldLeavesAfter: Duration? = nil, hasOwnScreen: Bool = true) {
        self.idle = idle; self.potential = potential; self.reference = reference; self.grant = grant
        self.responseDelay = responseDelay; self.rampDuration = rampDuration
        self.respondingStrategies = respondingStrategies
        self.preHeld = preHeld; self.preHeldLeavesAfter = preHeldLeavesAfter; self.hasOwnScreen = hasOwnScreen
    }

    /// Whether a request by `strategy` is answered.
    public func responds(to strategy: TriggerStrategy) -> Bool {
        respondingStrategies?.contains(strategy) ?? true
    }
}
