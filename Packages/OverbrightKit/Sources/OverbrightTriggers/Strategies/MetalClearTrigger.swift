// OverbrightTriggers/Strategies/MetalClearTrigger.swift — T2 and T3: a `CAMetalLayer` that shows one clear-only frame
// (no shaders, no library). ARCHITECTURE.md D4, D22, §4.7 (rungs 3–5), §8.1 rule 5. Thread: main; every wait is a
// stored `Task` sleeping on the injected `TimeSource`.
//
// - The first present is retried every 50 ms for up to 2 s, because the window may not yet be in the render tree.
// - After that T2 presents again only on events (`represent()`: wake, unlock, occlusion → visible, screen
//   parameters). T3 adds a keep-alive frame every 5 s, a stored `Task` cancelled by `remove()`.
// - `remove()` releases the device, the queue and the drawable pool so the driver can free its working set.
// - Generations (§4.6): a retry or keep-alive started for an earlier present or before `remove()` never presents.
import CoreGraphics
import OverbrightCore
import os
import QuartzCore

private let log = Log.logger(.trigger)

/// T2 (`TriggerStrategy.metalOneShot`) and T3 (`TriggerStrategy.metalKeepAlive`).
final class MetalClearTrigger: TriggerHandle, RegisteredWindowOwner {
    /// The rung.
    let request: TriggerRequest
    /// Frames presented successfully (first presents, retries, re-presents and keep-alive frames).
    private(set) var presentCount = 0
    /// The value the frames clear to (the last presented pixel's component).
    private(set) var value: Double?
    /// The tag last requested (only applied when `tagsLayer`).
    private(set) var headroomTag: Double
    /// `remove()` ran.
    private(set) var isRemoved = false
    /// Whether a keep-alive task is running (T3 after its first present).
    var isKeepingAlive: Bool { keepAlive != nil }

    private let host: TriggerHost
    private let surface: any ClearFrameSurface
    private let time: any TimeSource
    private let tagsLayer: Bool
    private weak var registry: TriggerWindowRegistry?
    private var generation: UInt64 = 0
    private var keepAlive: Task<Void, Never>?
    private var representTask: Task<Void, Never>?

    init(request: TriggerRequest, host: TriggerHost, surface: any ClearFrameSurface, time: any TimeSource,
         tagsLayer: Bool, registry: TriggerWindowRegistry?) {
        self.request = request
        self.host = host
        self.surface = surface
        self.time = time
        self.tagsLayer = tagsLayer
        self.headroomTag = request.headroomTag
        self.registry = registry
        if tagsLayer { surface.applyTag(request.headroomTag) }
        registry?.register(self)
    }

    /// A handle dropped without `remove()`: its tasks end and its device is released (the host closes the window).
    isolated deinit {
        keepAlive?.cancel()
        representTask?.cancel()
        surface.release()
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

    /// Shows `pixel`: orders the window in on the first call, then presents one frame, retrying every 50 ms for up to
    /// 2 s. True once a frame was presented; false after the retries, when the window could not be placed, when a
    /// newer present superseded this one, or after `remove()`. T3 starts (or restarts) its keep-alive on success.
    func present(_ pixel: TriggerPixel) async -> Bool {
        guard !isRemoved else { return false }
        generation &+= 1
        let current = generation
        cancelTasks()
        value = pixel.rawComponent
        if !host.hasWindow {
            do {
                try host.show(layer: surface.layer, blend: request.blend)
            } catch {
                log.error("T2 window failed on display \(self.host.display.id): \(LoggedError.publicSummary(error), privacy: .public)")
                return false
            }
        }
        guard await presentWithRetry(generation: current) else {
            if current == generation && !isRemoved {
                log.error("T2 never presented on display \(self.host.display.id) after \(TriggerTiming.firstPresentRetries) retries")
            }
            return false
        }
        if request.strategy == .metalKeepAlive { startKeepAlive(generation: current) }
        return true
    }

    /// Follows the screen geometry and presents one frame again (with the same retry), without waiting for it.
    func represent() {
        guard !isRemoved, value != nil else { return }
        host.reposition()
        representTask?.cancel()
        let current = generation
        representTask = Task { [weak self] in
            _ = await self?.presentWithRetry(generation: current)
        }
    }

    /// Records the tag; re-tags the layer in place and presents again only when the Metal layer is tagged
    /// (`TriggerEnvironment.tagsMetalLayers`); the default untagged layer ignores it (tag policy A).
    func requestHeadroom(_ headroom: Double) {
        guard !isRemoved else { return }
        headroomTag = headroom
        guard tagsLayer else { return }
        surface.applyTag(headroom)
        represent()
    }

    /// Cancels the retry and the keep-alive, orders the window out and releases the device. Idempotent.
    func remove() {
        guard !isRemoved else { return }
        isRemoved = true
        generation &+= 1
        cancelTasks()
        host.tearDown()
        surface.release()
        registry?.unregister(self)
    }

    // MARK: RegisteredWindowOwner

    /// Whether the window exists.
    var hasOpenWindow: Bool { host.hasWindow }

    // MARK: Private

    /// One attempt now, then one every `firstPresentRetryInterval` up to `firstPresentRetryLimit`. Stops as soon as
    /// the generation moves on.
    private func presentWithRetry(generation current: UInt64) async -> Bool {
        for attempt in 0...TriggerTiming.firstPresentRetries {
            if attempt > 0 {
                do { try await time.sleep(for: TriggerTiming.firstPresentRetryInterval) } catch { return false }
            }
            guard current == generation, !isRemoved else { return false }
            if presentFrame() { return true }
        }
        return false
    }

    private func startKeepAlive(generation current: UInt64) {
        keepAlive?.cancel()
        keepAlive = Task { [weak self, time] in
            while true {
                do { try await time.sleep(for: TriggerTiming.keepAliveInterval) } catch { return }
                guard let self, current == self.generation, !self.isRemoved else { return }
                _ = self.presentFrame()
            }
        }
    }

    private func presentFrame() -> Bool {
        guard let value, surface.presentFrame(value) else { return false }
        presentCount += 1
        return true
    }

    private func cancelTasks() {
        keepAlive?.cancel()
        keepAlive = nil
        representTask?.cancel()
        representTask = nil
    }
}
