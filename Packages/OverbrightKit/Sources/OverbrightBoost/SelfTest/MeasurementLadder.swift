// OverbrightBoost/SelfTest/MeasurementLadder.swift — the rungs the self-test measures and the calibration arms.
// ARCHITECTURE.md §4.7 (the ladder), §8.4 (the self-test arms the ladder from the top, ignoring the cache). Pure.
import OverbrightCore

/// One rung to measure: the trigger request, and whether this OS can show it at all.
nonisolated struct MeasurementRung: Hashable, Sendable {
    /// What the driver arms.
    var request: TriggerRequest
    /// False for T1 before macOS 26: reported as skipped, never armed.
    var isAvailable: Bool
}

/// The ladder of §4.7 from the top, without the strategy cache or any backoff (WP4's `LadderPlanner` adds those for the
/// engine): T1 black and 1.6 (macOS 26+), T2 black and 1.6, T3 1.6, T4 black, T4 at peak. "Test every method" adds the
/// in-memory HLG frame (T4-alt, hardware test H-T4d) and lists T1 as skipped on macOS 14–25.
nonisolated enum MeasurementLadder {
    /// T1 needs the tagged `CGColor` of macOS 26.
    static let taggedLayerMinimumOS = 26

    /// The rungs in order. `headroomTag` is the display's potential (tag policy A; T1 clamps it to ≥ 1.01).
    static func rungs(everyStrategy: Bool, machine: MachineIdentity, headroomTag: Double) -> [MeasurementRung] {
        let hasTaggedLayer = machine.osMajor >= taggedLayerMinimumOS
        var plan: [(TriggerStrategy, TriggerPixel)] = []
        if hasTaggedLayer || everyStrategy { plan += [(.taggedLayer, .black), (.taggedLayer, .bright)] }
        plan += [(.metalOneShot, .black), (.metalOneShot, .bright), (.metalKeepAlive, .bright)]
        if everyStrategy { plan.append((.hlgSampleBuffer, .black)) }
        plan += [(.hlgStill, .black), (.hlgStill, .bright)]
        let tag = max(headroomTag, 1.01)
        return plan.map { strategy, pixel in
            MeasurementRung(request: request(strategy, pixel, tag: tag),
                            isAvailable: strategy != .taggedLayer || hasTaggedLayer)
        }
    }

    /// A 1-pt trigger in the top-right corner; black blends normally, bright pixels blend soft-light (§4.7 placement).
    static func request(_ strategy: TriggerStrategy, _ pixel: TriggerPixel, tag: Double) -> TriggerRequest {
        TriggerRequest(strategy: strategy, pixel: pixel, placement: .topRightCorner,
                       blend: pixel == .black ? .normal : .softLight, edgePoints: 1, headroomTag: tag)
    }
}
