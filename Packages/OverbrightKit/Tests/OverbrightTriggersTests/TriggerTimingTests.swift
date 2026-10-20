// OverbrightTriggersTests/TriggerTimingTests.swift — the trigger-side timing constants match ARCHITECTURE.md §4.4
// (`firstPresentRetry`: every 50 ms for ≤ 2 s, the same numbers as Boost's `EngineTiming`) and §4.7 (T3 at 0.2 s, the
// cadence shipping boosters prove on the owner's built-in XDR; D4 as built).
import Testing
@testable import OverbrightTriggers

@Suite struct TriggerTimingTests {
    @Test func firstPresentIsRetriedEvery50msForTwoSeconds() {
        #expect(TriggerTiming.firstPresentRetryInterval == .milliseconds(50))
        #expect(TriggerTiming.firstPresentRetryLimit == .seconds(2))
        #expect(TriggerTiming.firstPresentRetries == 40)
    }

    /// Five presents a second: the proven cadence, paid for with a GPU working set that stays allocated while
    /// boosting (D4 as built); never so fast that the keep-alive becomes a render loop.
    @Test func keepAlivePresentsFiveTimesASecond() {
        #expect(TriggerTiming.keepAliveInterval == .milliseconds(200))
        #expect(TriggerTiming.keepAliveInterval >= .milliseconds(100), "a keep-alive, not a render loop")
    }

    @Test func hlgReadinessIsPolledLikeTheFirstPresent() {
        #expect(TriggerTiming.readinessPollInterval == .milliseconds(50))
        #expect(TriggerTiming.readinessLimit == .seconds(2))
        #expect(TriggerTiming.readinessPolls == 40)
    }
}
