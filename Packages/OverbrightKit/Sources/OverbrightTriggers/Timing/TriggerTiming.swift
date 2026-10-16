// OverbrightTriggers/Timing/TriggerTiming.swift — the trigger-side timing constants. ARCHITECTURE.md §4.4
// (`firstPresentRetry`), §4.7 (T3 keep-alive), §8.1 rule 5 (every periodic activity is a stored Task sleeping on the
// injected `TimeSource`). Boost's `EngineTiming` holds the engine's copy of the retry values; Triggers cannot import
// Boost (§2.1 rule 1), so `TriggerTimingTests` pins these to the numbers of §4.4 that `EngineTiming` also uses.

/// Timing of presents, retries and the keep-alive.
nonisolated enum TriggerTiming {
    /// T2/T3 retry a failed first present this often (the window may not be in the render tree yet).
    static let firstPresentRetryInterval: Duration = .milliseconds(50)
    /// …for at most this long; after it `present(_:)` returns false.
    static let firstPresentRetryLimit: Duration = .seconds(2)
    /// T3 presents one more clear-only frame this often. 5 s, not faster: below about 1 s the GPU working set stays
    /// allocated for good (0.2 s is a lab setting only, D4).
    static let keepAliveInterval: Duration = .seconds(5)
    /// HLG layers (T4, T4-alt) are polled this often until they report a frame ready for display…
    static let readinessPollInterval: Duration = .milliseconds(50)
    /// …for at most this long (a successful T4 present is "the layer became ready for display", §4.7).
    static let readinessLimit: Duration = .seconds(2)

    /// Number of retries after the first attempt: 40 (every 50 ms up to 2 s).
    static var firstPresentRetries: Int { Int((firstPresentRetryLimit / firstPresentRetryInterval).rounded(.down)) }
    /// Number of readiness polls after the first check: 40.
    static var readinessPolls: Int { Int((readinessLimit / readinessPollInterval).rounded(.down)) }
}
