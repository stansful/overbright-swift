// OverbrightCore/Model/Engine/DisplayStatus.swift — what the UI reads about one display. ARCHITECTURE.md §3.5.

/// What the UI, the menu, intents and diagnostics read about one display.
public nonisolated struct DisplayStatus: Hashable, Sendable {
    /// The display.
    public var key: DisplayKey
    /// `NSScreen.localizedName` (UI only).
    public var name: String
    /// The engine phase.
    public var phase: EnginePhase
    /// The latest policy decision.
    public var decision: DisplayDecision?
    /// Light gain on screen right now (1 = Standard; < 1 dimmed).
    public var appliedGain: Double
    /// Table factor written (or overlay factor) right now.
    public var appliedFactor: Double
    /// Table or overlay.
    public var mechanism: Mechanism
    /// The trigger strategy holding, if any.
    public var strategy: TriggerStrategy?
    /// The newest headroom reading.
    public var lastReading: HeadroomReading?
    /// Trusted SDR white; nits are shown only with this AND a valid calibration record (DESIGN.md §5.6).
    public var sdrWhite: SDRWhiteEstimate?
    /// `failed(headroomNeverArrived)` episodes in this session (the chip changes after two, DESIGN.md §12.2).
    public var failedTries: Int
    /// A display's status.
    public init(key: DisplayKey, name: String, phase: EnginePhase, decision: DisplayDecision?, appliedGain: Double,
                appliedFactor: Double, mechanism: Mechanism, strategy: TriggerStrategy?, lastReading: HeadroomReading?,
                sdrWhite: SDRWhiteEstimate?, failedTries: Int = 0) {
        self.key = key; self.name = name; self.phase = phase; self.decision = decision; self.appliedGain = appliedGain
        self.appliedFactor = appliedFactor; self.mechanism = mechanism; self.strategy = strategy
        self.lastReading = lastReading; self.sdrWhite = sdrWhite; self.failedTries = failedTries
    }
}
