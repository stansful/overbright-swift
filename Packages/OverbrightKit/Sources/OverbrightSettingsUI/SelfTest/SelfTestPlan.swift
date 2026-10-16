// OverbrightSettingsUI/SelfTest/SelfTestPlan.swift — the rungs the self-test measures on each display, in order, so the
// sheet can name the one under test and fill its progress bar (DESIGN.md §10). ARCHITECTURE.md §4.7, §8.4: the ladder
// from the top, ignoring the cache: the tagged layer black and bright (macOS 26 and later), the Metal layer black and
// bright, the refreshed Metal layer, the HDR video still black and at peak; "Test every method" adds the in-memory HDR
// frame and lists the tagged layer as skipped before macOS 26. The engine's runner (WP5's `MeasurementLadder`, which a
// UI module cannot import) is the authority; this is its order for display only. Pure (tested).
import OverbrightCore

/// The measured rungs of the self-test.
nonisolated enum SelfTestPlan {
    /// One rung: the method, the pixel it shows, and whether this macOS can show it at all (an unavailable rung is
    /// reported as skipped and takes no time).
    struct Rung: Hashable, Sendable {
        var strategy: TriggerStrategy
        var pixel: TriggerPixel
        var isAvailable: Bool
    }

    /// The tagged layer needs macOS 26.
    static let taggedLayerMinimumOS = 26

    /// The rungs of one display.
    static func rungs(everyMethod: Bool, machine: MachineIdentity) -> [Rung] {
        let hasTaggedLayer = machine.osMajor >= taggedLayerMinimumOS
        var plan: [(TriggerStrategy, TriggerPixel)] = []
        if hasTaggedLayer || everyMethod { plan += [(.taggedLayer, .black), (.taggedLayer, .bright)] }
        plan += [(.metalOneShot, .black), (.metalOneShot, .bright), (.metalKeepAlive, .bright)]
        if everyMethod { plan.append((.hlgSampleBuffer, .black)) }
        plan += [(.hlgStill, .black), (.hlgStill, .bright)]
        return plan.map { Rung(strategy: $0.0, pixel: $0.1, isAvailable: $0.0 != .taggedLayer || hasTaggedLayer) }
    }

    /// The rung that will be used from now on, judged from one display's results (DESIGN.md §10: "the cache is updated
    /// only from a clean pass"): the first that held, provided no rung was judged on a baseline something else held.
    static func cleanWinner(in results: [SelfTestStrategyResult]) -> SelfTestStrategyResult? {
        guard !results.contains(where: { $0.verdict == .invalidBaseline }) else { return nil }
        return results.first { $0.verdict == .held }
    }
}
