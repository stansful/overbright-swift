// OverbrightTriggersTests/HLGStillTriggerTests.swift — T4's readiness: a present succeeds only when the item it asked
// for is ready and on the layer, and a level switch never trusts the readiness the layer still reports for the
// previous item. ARCHITECTURE.md §4.7 (rungs 6–7: "a successful T4 present is the layer becoming ready for display"),
// §10.5. The window is only recorded (never ordered in), the player is never played, and the stills go to a temporary
// folder.
import AVFoundation
import Foundation
import OverbrightCore
import OverbrightTestSupport
import QuartzCore
import Testing
@testable import OverbrightTriggers

@Suite struct HLGStillTriggerTests {
    /// A player layer that always says it has a frame ready: the stale "yes" a real layer can still give right after
    /// `replaceCurrentItem`, before the new item has a frame. Nonisolated like the `CALayer` initialisers it inherits.
    nonisolated final class AlwaysReadyPlayerLayer: AVPlayerLayer {
        override var isReadyForDisplay: Bool { true }

        /// A layer showing `player`.
        static func showing(_ player: AVPlayer) -> AlwaysReadyPlayerLayer {
            let layer = AlwaysReadyPlayerLayer()
            layer.player = player
            return layer
        }
    }

    /// The outcome of a present running in its own task.
    final class PresentOutcome {
        /// Nil while the present runs.
        var value: Bool?
    }

    private func trigger(_ bed: TriggerTestBed) -> HLGStillTrigger {
        let host = TriggerHost(display: TriggerTestBed.builtIn,
                               shape: .trigger(placement: .topRightCorner, edgePoints: 1), screens: bed.screens,
                               presenter: bed.presenter)
        return HLGStillTrigger(request: TriggerTestBed.request(.hlgStill), host: host, stills: bed.stills,
                               time: bed.time, registry: nil, makeLayer: { AlwaysReadyPlayerLayer.showing($0) })
    }

    /// Starts `present(pixel)` in a task and records its result.
    private func start(_ trigger: HLGStillTrigger, _ pixel: TriggerPixel) -> PresentOutcome {
        let outcome = PresentOutcome()
        Task { outcome.value = await trigger.present(pixel) }
        return outcome
    }

    /// Lets the present finish: each time it sleeps, the manual clock moves one poll interval on, after a short real
    /// pause in which AVFoundation can load the item. At most the 2 s readiness limit's worth of polls.
    private func finish(_ outcome: PresentOutcome, _ bed: TriggerTestBed) async -> Bool? {
        for _ in 0...TriggerTiming.readinessPolls {
            _ = await eventually { outcome.value != nil || bed.time.sleeperCount > 0 }
            if let value = outcome.value { return value }
            try? await Task.sleep(for: .milliseconds(20))
            await bed.time.advance(by: TriggerTiming.readinessPollInterval)
        }
        _ = await eventually(timeout: .seconds(5)) { outcome.value != nil }
        return outcome.value
    }

    private func fileName(of item: AVPlayerItem?) -> String? {
        (item?.asset as? AVURLAsset)?.url.lastPathComponent
    }

    @Test func aPresentSucceedsOnlyOnceItsItemIsReadyToPlay() async throws {
        let bed = TriggerTestBed(codecs: [.proRes422])
        let trigger = trigger(bed)
        let outcome = start(trigger, .black)
        // The layer says "ready" from the start; the item still has to load before the present trusts it.
        #expect(await eventually { bed.time.sleeperCount == 1 }, "the first check failed: the item was not loaded")
        #expect(outcome.value == nil)
        #expect(await finish(outcome, bed) == true)
        let item = try #require(trigger.player?.currentItem)
        #expect(item.status == .readyToPlay)
        #expect(fileName(of: item) == "hlg-still-v1-proRes422-black-16.mov")
        #expect(bed.presenter.orderedIn.count == 1)
        trigger.remove()
        #expect(bed.presenter.orderedOut.count == 1)
    }

    @Test func aLevelSwitchNeverTrustsTheReadinessOfThePreviousItem() async throws {
        let bed = TriggerTestBed(codecs: [.proRes422])
        let trigger = trigger(bed)
        #expect(await finish(start(trigger, .black), bed) == true)
        let black = try #require(trigger.player?.currentItem)
        #expect(black.status == .readyToPlay)
        // Switch to peak while the layer still reports the black frame as ready.
        let outcome = start(trigger, .bright)
        #expect(await eventually { bed.time.sleeperCount == 1 }, "the switch waits a poll interval before any check")
        #expect(outcome.value == nil, "a stale ready from the previous item is never reported")
        let peak = try #require(trigger.player?.currentItem)
        #expect(peak !== black)
        #expect(fileName(of: peak) == "hlg-still-v1-proRes422-peak-16.mov")
        #expect(await finish(outcome, bed) == true)
        #expect(peak.status == .readyToPlay)
        #expect(trigger.shownLevel == .peak)
        #expect(bed.presenter.orderedIn.count == 1, "one window for both levels")
        trigger.remove()
    }

    @Test func theSameLevelAgainChecksAtOnce() async throws {
        let bed = TriggerTestBed(codecs: [.proRes422])
        let trigger = trigger(bed)
        #expect(await finish(start(trigger, .sdrWhite), bed) == true)
        let item = trigger.player?.currentItem
        let outcome = start(trigger, .sdrWhite)
        #expect(await eventually { outcome.value != nil })
        #expect(outcome.value == true)
        #expect(trigger.player?.currentItem === item, "the item is kept")
        #expect(bed.time.sleeperCount == 0)
        trigger.remove()
    }
}
