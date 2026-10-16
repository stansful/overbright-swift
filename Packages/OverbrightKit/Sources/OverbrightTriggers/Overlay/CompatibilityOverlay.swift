// OverbrightTriggers/Overlay/CompatibilityOverlay.swift — technique C ("Compatibility mode"): one full-screen,
// click-through, capture-excluded window per display whose single layer is composited with `multiplyBlendMode`, so
// everything beneath is multiplied by F. ARCHITECTURE.md D4, §4.3 (overlay rows), §7.5, §7.6. Thread: main.
//
// - F > 1 boosts: the overlay is itself the EDR request, so this mode has no trigger window. Request first, then
//   boost: the engine shows factor 1 with `headroomRequest = target ÷ 0.97`, waits for the gate, then ramps the factor.
// - F < 1 dims without any EDR request (an untagged colour), so dimming works where table writes are ignored.
// - Factor 1 at the begin phase of a reconfiguration: after the first call (which builds and orders in the window),
//   `setFactor` changes only the layer's colour (or presents one clear frame); it never queries a display.
// - Surfaces: a headroom-tagged `CALayer` colour on macOS 26+ (no Metal); a 4 × 4 px clear-only `CAMetalLayer`
//   drawable stretched with nearest filtering on 14–25.
// The multiply-overlay idea is credited to xdr-boost (MIT); this code is independent.
import CoreGraphics
import OverbrightCore
import os
import QuartzCore

private let log = Log.logger(.trigger)

/// One Compatibility-mode overlay (`OverlayHandle`).
final class CompatibilityOverlay: OverlayHandle, RegisteredWindowOwner {
    /// How the multiply colour is drawn.
    enum Surface: Hashable, Sendable {
        /// macOS 26+: a plain `CALayer` with a (tagged) background colour.
        case taggedColor
        /// macOS 14+: a `CAMetalLayer` with a 4 × 4 px clear-only drawable.
        case metal
    }

    /// Core Animation's multiply blend (the string form `compositingFilter` accepts).
    static let multiplyFilter = "multiplyBlendMode"
    /// The Metal surface's drawable edge in pixels.
    static let metalDrawablePixels = 4

    /// The surface in use.
    let surface: Surface
    /// The factor on screen (1 before the first call).
    private(set) var factor: Double = 1
    /// The headroom asked for now (≥ `factor`; 1 means no EDR request).
    private(set) var headroomRequest: Double = 1
    /// `remove()` ran.
    private(set) var isRemoved = false
    /// The layer the window hosts, once shown.
    private(set) var layer: CALayer?

    private let host: TriggerHost
    private let clearSurface: (any ClearFrameSurface)?
    private let time: any TimeSource
    private weak var registry: TriggerWindowRegistry?
    private var generation: UInt64 = 0
    private var retryTask: Task<Void, Never>?

    /// `clearSurface` is required for (and used only by) the `.metal` surface.
    init(host: TriggerHost, surface: Surface, clearSurface: (any ClearFrameSurface)?, time: any TimeSource,
         registry: TriggerWindowRegistry?) {
        self.host = host
        self.surface = surface
        self.clearSurface = clearSurface
        self.time = time
        self.registry = registry
        registry?.register(self)
    }

    /// An overlay dropped without `remove()`: its retry ends and its surface is released (the host closes the window).
    isolated deinit {
        retryTask?.cancel()
        clearSurface?.release()
    }

    /// Whether an overlay colour for (`factor`, `request`) requests EDR: only a request above 1.
    nonisolated static func wantsEDR(factor: Double, headroomRequest: Double) -> Bool {
        max(factor, headroomRequest) > 1
    }

    // MARK: OverlayHandle

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

    /// Multiplies the screen by `factor` and asks for at least `headroomRequest` (kept ≥ `factor`). The first call
    /// builds the full-screen window and orders it in (throws `TriggerError.displayGone` without a screen,
    /// `.colorUnavailable` without the colour space, `.needsNewerMacOS(26)` for a tagged surface before 26); later
    /// calls change the colour at once. A factor above the granted headroom only clips at H; it never flashes.
    func setFactor(_ factor: Double, headroomRequest: Double) throws {
        guard !isRemoved else { throw TriggerError.displayGone }
        let newFactor = factor.isFinite ? max(factor, 0) : 1
        let newRequest = max(newFactor, headroomRequest.isFinite ? headroomRequest : 1)
        if layer == nil { try show() }
        try apply(factor: newFactor, headroomRequest: newRequest)
        self.factor = newFactor
        self.headroomRequest = newRequest
    }

    /// Follows the screen's frame and shows the current factor again.
    func represent() {
        guard !isRemoved, layer != nil else { return }
        host.reposition()
        do {
            try apply(factor: factor, headroomRequest: headroomRequest)
        } catch {
            log.error("Overlay re-present failed on display \(self.host.display.id): \(String(describing: error), privacy: .public)")
        }
    }

    /// Orders the window out and releases the surface. Idempotent.
    func remove() {
        guard !isRemoved else { return }
        isRemoved = true
        generation &+= 1
        retryTask?.cancel()
        retryTask = nil
        host.tearDown()
        clearSurface?.release()
        layer = nil
        registry?.unregister(self)
    }

    // MARK: RegisteredWindowOwner

    /// Whether the window exists.
    var hasOpenWindow: Bool { host.hasWindow }

    // MARK: Private

    private func show() throws {
        let newLayer: CALayer
        switch surface {
        case .taggedColor:
            guard #available(macOS 26.0, *) else { throw TriggerError.needsNewerMacOS(26) }
            newLayer = CALayer()
            newLayer.isOpaque = true
        case .metal:
            guard let clearSurface else { throw TriggerError.noMetalDevice }
            newLayer = clearSurface.layer
        }
        newLayer.compositingFilter = Self.multiplyFilter
        try host.show(layer: newLayer, blend: .normal)
        layer = newLayer
    }

    private func apply(factor: Double, headroomRequest: Double) throws {
        let wantsEDR = Self.wantsEDR(factor: factor, headroomRequest: headroomRequest)
        switch surface {
        case .taggedColor:
            guard #available(macOS 26.0, *), let layer else { return }
            let color = wantsEDR
                ? TaggedColor.cgColor(value: factor, headroom: TaggedColor.edrTag(headroomRequest))
                : TaggedColor.untaggedCGColor(value: factor)
            guard let color else { throw TriggerError.colorUnavailable }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.preferredDynamicRange = wantsEDR ? .high : .standard
            layer.backgroundColor = color
            CATransaction.commit()
        case .metal:
            guard let clearSurface else { return }
            clearSurface.setWantsEDR(wantsEDR)
            generation &+= 1
            retryTask?.cancel()
            retryTask = nil
            if !clearSurface.presentFrame(factor) { retryFrame(factor, surface: clearSurface, generation: generation) }
        }
    }

    /// The first frame can fail while the window is not yet in the render tree: retry like T2 (every 50 ms, ≤ 2 s).
    private func retryFrame(_ value: Double, surface: any ClearFrameSurface, generation current: UInt64) {
        retryTask = Task { [weak self, time] in
            for _ in 0..<TriggerTiming.firstPresentRetries {
                do { try await time.sleep(for: TriggerTiming.firstPresentRetryInterval) } catch { return }
                guard let self, current == self.generation, !self.isRemoved else { return }
                if surface.presentFrame(value) { return }
            }
            log.error("Overlay frame never presented")
        }
    }
}
