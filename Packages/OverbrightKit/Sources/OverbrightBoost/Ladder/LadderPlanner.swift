// OverbrightBoost/Ladder/LadderPlanner.swift — which rungs a display tries, in which order. ARCHITECTURE.md §4.7, D4,
// D6 (pre-held displays start at the cheapest rung). Pure and nonisolated: the controller passes the OS, the cache,
// the override, the backoff state and the factory's available strategies in.
import OverbrightCore

/// Plans the rung list of one arm and the `TriggerRequest` of each rung.
nonisolated enum LadderPlanner {
    /// Hardware test H-T4d decides whether rung 6 is the in-memory HLG frame (`hlgSampleBuffer`) or our own HLG still.
    /// Until it passes, rung 6 uses the still (WP16 flips this).
    static let usesSampleBufferHLG = false

    /// Every rung of §4.7, by number (numbers are what the strategy cache stores).
    static var table: [LadderRung] {
        [LadderRung(number: 1, strategy: .taggedLayer, pixel: .black, minimumOS: 26),
         LadderRung(number: 2, strategy: .taggedLayer, pixel: .bright, minimumOS: 26),
         LadderRung(number: 3, strategy: .metalOneShot, pixel: .black),
         LadderRung(number: 4, strategy: .metalOneShot, pixel: .bright),
         LadderRung(number: 5, strategy: .metalKeepAlive, pixel: .bright),
         LadderRung(number: 6, strategy: usesSampleBufferHLG ? .hlgSampleBuffer : .hlgStill, pixel: .black),
         LadderRung(number: 7, strategy: .hlgStill, pixel: .bright)]
    }

    /// The automatic order, by rung number. The owner's hardware (MacBook Pro M4 Max, macOS 27.0.1, built-in XDR,
    /// 2026-10-20) turned white when a table was scaled behind a tagged-layer trigger (rungs 1–2), although
    /// `maximumExtendedDynamicRangeColorComponentValue` rose from 1.2 to 4.0 for it; a re-presented bright Metal pixel is
    /// the recipe shipping boosters have proven on that panel. So the automatic ladder starts there and leaves the
    /// tagged layer to Advanced ▸ Trigger method (D4 as built, §4.7).
    static let automaticOrder = [5, 4, 3, 6, 7]

    /// The automatic ladder, in order.
    static var automatic: [LadderRung] {
        automaticOrder.compactMap { number in table.first { $0.number == number } }
    }

    /// The rungs of one arm, cheapest first.
    /// - Parameters:
    ///   - facts: the display (an external's non-black rungs blend softly).
    ///   - isOLED: OLED displays use black rungs only unless a strategy is pinned (burn-in care, §4.7).
    ///   - os: the macOS major version (T1 needs 26; 14–25 start at T2).
    ///   - cache: the cached winning rung number for this display and OS build; the arm starts there.
    ///   - override: Advanced ▸ Trigger method: only that strategy's rungs.
    ///   - backoff: a wake or unlock backoff retries the cached rung only and never escalates (§4.3, §4.7).
    ///   - available: the strategies the factory can make on this Mac.
    static func rungs(for facts: DisplayFacts, isOLED: Bool, os: Int, cache: Int?, override: TriggerStrategy?,
                             backoff: Bool, available: Set<TriggerStrategy>) -> [LadderRung] {
        _ = facts
        if let override {
            let pinned = table.filter { os >= $0.minimumOS && available.contains($0.strategy) && $0.strategy == override }
            if !pinned.isEmpty { return backoff ? Array(pinned.prefix(1)) : pinned }
        }
        let runnable = automatic.filter { os >= $0.minimumOS && available.contains($0.strategy) }
        let ladder = isOLED ? runnable.filter { $0.pixel == .black } : runnable
        guard !ladder.isEmpty else { return [] }
        var start = 0
        if let cache, let index = ladder.firstIndex(where: { $0.number == cache }) { start = index }
        return backoff ? [ladder[start]] : Array(ladder[start...])
    }

    /// The factory request of `rung` on a display (§4.7 placement and blending, headroom tag policy A).
    /// - Parameter potential: the display's potential headroom (the tag, so the tag can never cap the grant).
    static func request(for rung: LadderRung, facts: DisplayFacts, potential: Double) -> TriggerRequest {
        let blend: TriggerBlend = !facts.isBuiltIn && rung.pixel != .black ? .softLight : .normal
        return TriggerRequest(strategy: rung.strategy, pixel: rung.pixel, placement: .topRightCorner, blend: blend,
                              headroomTag: max(potential, 1))
    }
}
