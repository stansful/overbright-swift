// OverbrightTriggers/Strategies/HLGStillTrigger.swift — T4: frame 0 of our own HLG still in a paused `AVPlayerLayer`.
// ARCHITECTURE.md D4, §4.7 (rungs 6–7, "HLG still asset"), §4.6 (asset generations). Thread: main; the still is
// generated and verified off the main actor (`HLGStillCache` → `HLGStillAsset.ensureCached`).
//
// AVFoundation shows HLG video as EDR without any app code, so a paused HDR frame on screen is a Metal-free trigger.
// `play()` is never called, the player never holds a display-sleep assertion, and HLG content implies its own
// headroom (1000 ÷ 203 ≈ 4.93), so `requestHeadroom(_:)` has nothing to change.
//
// Readiness: a present succeeds only when the player shows the item this present asked for, that item is ready to
// play and the layer has a frame ready for display. After a level switch (`replaceCurrentItem`) the layer may still
// report the previous item's frame as ready, so the first check waits one poll interval.
import AVFoundation
import CoreGraphics
import OverbrightCore
import os
import QuartzCore

private let log = Log.logger(.trigger)

/// T4 (`TriggerStrategy.hlgStill`).
final class HLGStillTrigger: TriggerHandle, RegisteredWindowOwner {
    /// The rung.
    let request: TriggerRequest
    /// The level on screen, once presented.
    private(set) var shownLevel: HLGStillAsset.Level?
    /// `remove()` ran.
    private(set) var isRemoved = false

    private let host: TriggerHost
    private let stills: HLGStillCache
    private let time: any TimeSource
    private weak var registry: TriggerWindowRegistry?
    private let makeLayer: (AVPlayer) -> AVPlayerLayer
    private(set) var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var generation: UInt64 = 0

    /// `makeLayer` builds the layer around the player (a plain `AVPlayerLayer`; tests substitute one whose readiness
    /// they control).
    init(request: TriggerRequest, host: TriggerHost, stills: HLGStillCache, time: any TimeSource,
         registry: TriggerWindowRegistry?,
         makeLayer: @escaping (AVPlayer) -> AVPlayerLayer = { AVPlayerLayer(player: $0) }) {
        self.request = request
        self.host = host
        self.stills = stills
        self.time = time
        self.registry = registry
        self.makeLayer = makeLayer
        registry?.register(self)
    }

    /// A handle dropped without `remove()` releases its player item (the host closes the window).
    isolated deinit {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
    }

    // MARK: TriggerHandle

    /// Hidden by the lock shield or another window.
    var isOccluded: Bool { host.isOccluded }
    /// Forwarded to the window.
    var onOcclusionChange: ((Bool) -> Void)? {
        get { host.onOcclusionChange }
        set { host.onOcclusionChange = newValue }
    }
    /// Forwarded to the window.
    var onScreenChange: ((CGDirectDisplayID?) -> Void)? {
        get { host.onScreenChange }
        set { host.onScreenChange = newValue }
    }

    /// Shows the still for `pixel` (black, reference white or peak): waits for the verified asset, puts it in a
    /// paused player (ordering the window in on the first call), then waits up to 2 s for that item to be on screen
    /// (ready to play, and the layer ready for display). False when no still could be made, the window could not be
    /// placed, the frame never became ready, a newer present superseded this one, or after `remove()`.
    func present(_ pixel: TriggerPixel) async -> Bool {
        guard !isRemoved else { return false }
        generation &+= 1
        let current = generation
        let level = HLGStillAsset.Level(pixel)
        guard let url = await stills.url(for: level) else { return false }
        guard current == generation, !isRemoved else { return false }
        if let player, let playerLayer {
            if shownLevel == level { return await waitUntilReady(playerLayer, generation: current, checkAtOnce: true) }
            player.replaceCurrentItem(with: AVPlayerItem(url: url))
            shownLevel = level
            // The layer can still report the previous item's frame: never trust a check made before a poll interval.
            return await waitUntilReady(playerLayer, generation: current, checkAtOnce: false)
        }
        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.isMuted = true
        newPlayer.actionAtItemEnd = .pause
        newPlayer.preventsDisplaySleepDuringVideoPlayback = false   // never a display-sleep assertion
        newPlayer.allowsExternalPlayback = false
        let layer = makeLayer(newPlayer)
        layer.videoGravity = .resizeAspectFill
        do {
            try host.show(layer: layer, blend: request.blend)
        } catch {
            log.error("T4 window failed on display \(self.host.display.id): \(LoggedError.publicSummary(error), privacy: .public)")
            return false
        }
        player = newPlayer
        playerLayer = layer
        shownLevel = level
        return await waitUntilReady(layer, generation: current, checkAtOnce: true)
    }

    /// Follows the screen geometry and seeks back to frame 0, which shows it again.
    func represent() {
        guard !isRemoved, let player else { return }
        host.reposition()
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    /// HLG content carries its own implied headroom; there is no tag to change.
    func requestHeadroom(_ headroom: Double) { _ = headroom }

    /// Releases the player item, orders the window out. Idempotent.
    func remove() {
        guard !isRemoved else { return }
        isRemoved = true
        generation &+= 1
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        playerLayer = nil
        host.tearDown()
        registry?.unregister(self)
    }

    // MARK: RegisteredWindowOwner

    /// Whether the window exists.
    var hasOpenWindow: Bool { host.hasWindow }

    // MARK: Private

    /// Whether `layer` shows its player's current item: the item is ready to play and the layer has a frame ready.
    static func isShowingCurrentItem(_ layer: AVPlayerLayer) -> Bool {
        guard let item = layer.player?.currentItem, item.status == .readyToPlay else { return false }
        return layer.isReadyForDisplay
    }

    /// Polls every 50 ms for up to 2 s (`TriggerTiming`). `checkAtOnce` false skips the check before the first sleep
    /// (after `replaceCurrentItem`), so the 2 s limit holds either way.
    private func waitUntilReady(_ layer: AVPlayerLayer, generation current: UInt64, checkAtOnce: Bool) async -> Bool {
        for poll in (checkAtOnce ? 0 : 1)...TriggerTiming.readinessPolls {
            if poll > 0 {
                do { try await time.sleep(for: TriggerTiming.readinessPollInterval) } catch { return false }
            }
            guard current == generation, !isRemoved else { return false }
            if Self.isShowingCurrentItem(layer) { return true }
        }
        log.error("T4 still never became ready on display \(self.host.display.id)")
        return false
    }
}
