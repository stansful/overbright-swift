// OverbrightTriggers/Strategies/HLGStillTrigger.swift — T4: frame 0 of our own HLG still in a paused `AVPlayerLayer`.
// ARCHITECTURE.md D4, §4.7 (rungs 6–7, "HLG still asset"), §4.6 (asset generations). Thread: main; the still is
// generated and verified off the main actor (`HLGStillCache` → `HLGStillAsset.ensureCached`).
//
// AVFoundation shows HLG video as EDR without any app code, so a paused HDR frame on screen is a Metal-free trigger.
// `play()` is never called, the player never holds a display-sleep assertion, and HLG content implies its own
// headroom (1000 ÷ 203 ≈ 4.93), so `requestHeadroom(_:)` has nothing to change.
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
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var generation: UInt64 = 0

    init(request: TriggerRequest, host: TriggerHost, stills: HLGStillCache, time: any TimeSource,
         registry: TriggerWindowRegistry?) {
        self.request = request
        self.host = host
        self.stills = stills
        self.time = time
        self.registry = registry
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
    /// paused player (ordering the window in on the first call), then waits up to 2 s for the layer to have a frame
    /// ready for display. False when no still could be made, the window could not be placed, the frame never became
    /// ready, a newer present superseded this one, or after `remove()`.
    func present(_ pixel: TriggerPixel) async -> Bool {
        guard !isRemoved else { return false }
        generation &+= 1
        let current = generation
        let level = HLGStillAsset.Level(pixel)
        guard let url = await stills.url(for: level) else { return false }
        guard current == generation, !isRemoved else { return false }
        if let player, let playerLayer {
            if shownLevel != level { player.replaceCurrentItem(with: AVPlayerItem(url: url)) }
            shownLevel = level
            return await waitUntilReady(playerLayer, generation: current)
        }
        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.isMuted = true
        newPlayer.actionAtItemEnd = .pause
        newPlayer.preventsDisplaySleepDuringVideoPlayback = false   // never a display-sleep assertion
        newPlayer.allowsExternalPlayback = false
        let layer = AVPlayerLayer(player: newPlayer)
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
        return await waitUntilReady(layer, generation: current)
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

    private func waitUntilReady(_ layer: AVPlayerLayer, generation current: UInt64) async -> Bool {
        for poll in 0...TriggerTiming.readinessPolls {
            if poll > 0 {
                do { try await time.sleep(for: TriggerTiming.readinessPollInterval) } catch { return false }
            }
            guard current == generation, !isRemoved else { return false }
            if layer.isReadyForDisplay { return true }
        }
        log.error("T4 still never became ready on display \(self.host.display.id)")
        return false
    }
}
