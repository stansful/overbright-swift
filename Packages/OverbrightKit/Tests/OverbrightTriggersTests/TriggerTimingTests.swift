// OverbrightTriggersTests/TriggerTimingTests.swift — the trigger-side timing constants match ARCHITECTURE.md §4.4
// (`firstPresentRetry`: every 50 ms for ≤ 2 s, the same numbers as Boost's `EngineTiming`) and §4.7 (T3 at 5 s, never
// the 0.2 s lab cadence).
import Testing
@testable import OverbrightTriggers

@Suite struct TriggerTimingTests {
    @Test func firstPresentIsRetriedEvery50msForTwoSeconds() {
        #expect(TriggerTiming.firstPresentRetryInterval == .milliseconds(50))
        #expect(TriggerTiming.firstPresentRetryLimit == .seconds(2))
        #expect(TriggerTiming.firstPresentRetries == 40)
    }

    @Test func keepAliveIsSlowEnoughToFreeTheGPUWorkingSet() {
        #expect(TriggerTiming.keepAliveInterval == .seconds(5))
        #expect(TriggerTiming.keepAliveInterval >= .seconds(2), "below about 2 s the working set stays allocated")
    }

    @Test func hlgReadinessIsPolledLikeTheFirstPresent() {
        #expect(TriggerTiming.readinessPollInterval == .milliseconds(50))
        #expect(TriggerTiming.readinessLimit == .seconds(2))
        #expect(TriggerTiming.readinessPolls == 40)
    }
}
