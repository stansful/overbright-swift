// OverbrightSignals/Idle/IdleScheduler.swift — the OLED idle pause, scheduled without polling. ARCHITECTURE.md §7.1
// ("Idle time": boost-only, OLED), §7.3, D10, D22.
// System idle time is `CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: any input)`: a timestamp
// read, no Input Monitoring or Accessibility [VERIFIED]. While boosted on an OLED display, ONE deadline waits for
// `threshold − idle`; once idle, the time is re-read every 2 s until input returns (the state is "paused", not "off").
// While any process keeps the display awake (video), idle does not count.
// Thread: any (pure; `SignalsMonitor` runs the deadline on the main actor).
import Foundation

/// The pure decision behind the idle deadline.
nonisolated enum IdleScheduler {
    /// Re-read interval while idle, waiting for input.
    static let inputPollInterval: Duration = .seconds(2)
    /// Slack added to a deadline so the read after it lands past the threshold.
    static let margin: Duration = .milliseconds(100)

    /// One decision.
    struct Decision: Hashable, Sendable {
        /// `SystemSnapshot.isIdleBeyondThreshold`.
        var isIdle: Bool
        /// When to read again.
        var nextCheck: Duration
    }

    /// Decides from one read. `secondsSinceInput` nil (the read failed) or a display held awake → not idle, read again
    /// after one threshold; idle beyond the threshold → idle, poll for input every 2 s; otherwise → wait for the rest.
    static func evaluate(secondsSinceInput: Double?, threshold: Duration, displayHeldAwake: Bool) -> Decision {
        guard let idle = secondsSinceInput, idle.isFinite, idle >= 0, !displayHeldAwake else {
            return Decision(isIdle: false, nextCheck: threshold)
        }
        let remaining = threshold - .milliseconds(Int64((idle * 1000).rounded(.down)))
        if remaining <= .zero { return Decision(isIdle: true, nextCheck: inputPollInterval) }
        return Decision(isIdle: false, nextCheck: remaining + margin)
    }

    /// The threshold of `automations.oledIdleMinutes` (allowed 1, 2, 5, 10, 15, 30; anything else is clamped to 1…30).
    static func threshold(minutes: Int) -> Duration {
        .seconds(60 * min(max(minutes, 1), 30))
    }
}
