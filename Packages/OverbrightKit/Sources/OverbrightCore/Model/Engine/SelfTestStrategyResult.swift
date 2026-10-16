// OverbrightCore/Model/Engine/SelfTestStrategyResult.swift — one rung's self-test result. ARCHITECTURE.md §3.5, §8.4.

/// The self-test result of one rung on one display.
public nonisolated struct SelfTestStrategyResult: Hashable, Codable, Sendable {
    /// What the rung did.
    public enum Verdict: String, Codable, Sendable {
        /// Headroom rose and held.
        case held
        /// Headroom rose, then dropped.
        case engagedButDropped
        /// Headroom never moved.
        case noEngage
        /// H0 was already pre-held: the rung cannot be judged.
        case invalidBaseline
        /// Not available on this Mac or OS.
        case skipped
    }
    /// The strategy tested.
    public var strategy: TriggerStrategy
    /// The pixel shown.
    public var pixel: TriggerPixel
    /// The outcome.
    public var verdict: Verdict
    /// H0 before arming.
    public var baselineHeadroom: Double
    /// Seconds to the first movement.
    public var secondsToFirstMovement: Double?
    /// Seconds to a stable value.
    public var secondsToStable: Double?
    /// Fraction of the time the grant held.
    public var heldFraction: Double
    /// The samples.
    public var samples: [SelfTestSample]
    /// A result.
    public init(strategy: TriggerStrategy, pixel: TriggerPixel, verdict: Verdict, baselineHeadroom: Double,
                secondsToFirstMovement: Double?, secondsToStable: Double?, heldFraction: Double,
                samples: [SelfTestSample]) {
        self.strategy = strategy; self.pixel = pixel; self.verdict = verdict; self.baselineHeadroom = baselineHeadroom
        self.secondsToFirstMovement = secondsToFirstMovement; self.secondsToStable = secondsToStable
        self.heldFraction = heldFraction; self.samples = samples
    }
}
