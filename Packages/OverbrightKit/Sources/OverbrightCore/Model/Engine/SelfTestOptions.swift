// OverbrightCore/Model/Engine/SelfTestOptions.swift — what a self-test run covers. ARCHITECTURE.md §3.5, §8.4.

/// What a self-test run covers.
public nonisolated struct SelfTestOptions: Hashable, Sendable {
    /// Test every rung of the ladder instead of stopping at the first that holds.
    public var everyStrategy: Bool
    /// How long each strategy is measured.
    public var secondsPerStrategy: Int
    /// The displays to test; nil = every capable display.
    public var displays: Set<DisplayKey>?
    /// Options; the first rung that holds, 30 s, every display by default.
    public init(everyStrategy: Bool = false, secondsPerStrategy: Int = 30, displays: Set<DisplayKey>? = nil) {
        self.everyStrategy = everyStrategy; self.secondsPerStrategy = secondsPerStrategy; self.displays = displays
    }
}
