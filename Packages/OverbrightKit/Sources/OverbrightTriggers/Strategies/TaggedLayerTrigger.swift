// OverbrightTriggers/Strategies/TaggedLayerTrigger.swift — T1: a plain `CALayer` that asks for EDR through a
// headroom-tagged colour (macOS 26+). ARCHITECTURE.md D4, §4.7 (rungs 1–2, tag policy A/B, T1 tag precision).
// Thread: main.
//
// CALayer.h (macOS 27 SDK): `preferredDynamicRange` "requires that the layer contain a CGColor or `contents' with
// headroom tagging greater than 1.0 in order to activate EDR". No Metal, no frames, no timers: one Core Animation
// commit. The macOS 14–25 legacy path (the deprecated `CALayer` EDR flag with an untagged extended colour) is compiled
// behind `TriggerEnvironment.allowsLegacyLayerPath`, off until a real 14/15 Mac shows it holds.
import CoreGraphics
import OverbrightCore
import os
import QuartzCore

private let log = Log.logger(.trigger)

/// T1 (`TriggerStrategy.taggedLayer`).
final class TaggedLayerTrigger: TriggerHandle, RegisteredWindowOwner {
    /// The rung.
    let request: TriggerRequest
    /// The tag the layer carries now (before the 1.01 clamp); starts at the request's tag.
    private(set) var headroomTag: Double
    /// The pixel shown, once presented.
    private(set) var shownPixel: TriggerPixel?
    /// The layer, once presented.
    private(set) var layer: CALayer?
    /// `remove()` ran.
    private(set) var isRemoved = false

    private let host: TriggerHost
    private let allowsLegacyPath: Bool
    private weak var registry: TriggerWindowRegistry?

    init(request: TriggerRequest, host: TriggerHost, allowsLegacyPath: Bool, registry: TriggerWindowRegistry?) {
        self.request = request
        self.headroomTag = request.headroomTag
        self.host = host
        self.allowsLegacyPath = allowsLegacyPath
        self.registry = registry
        registry?.register(self)
    }

    /// T1 needs a tag above 1.0, and tags ≤ 1.0001 read back as 1.0, so a tag is raised to at least 1.01.
    nonisolated static func effectiveTag(_ requested: Double) -> Double { TaggedColor.edrTag(requested) }

    /// The layer for `pixel` with `headroomTag`, built without showing it: on macOS 26+ a tagged colour with
    /// `preferredDynamicRange = .high` (`.constrainedHigh` would modulate brightness "for co-existence"); before 26
    /// the legacy path when allowed, else `TriggerError.needsNewerMacOS(26)`.
    static func makeLayer(pixel: TriggerPixel, headroomTag: Double, allowsLegacyPath: Bool) throws -> CALayer {
        let layer = CALayer()
        layer.isOpaque = true
        try apply(pixel: pixel, headroomTag: headroomTag, to: layer, allowsLegacyPath: allowsLegacyPath)
        return layer
    }

    private static func apply(pixel: TriggerPixel, headroomTag: Double, to layer: CALayer,
                              allowsLegacyPath: Bool) throws {
        if #available(macOS 26.0, *) {
            guard let color = TaggedColor.cgColor(value: pixel.rawComponent, headroom: effectiveTag(headroomTag)) else {
                throw TriggerError.colorUnavailable
            }
            layer.backgroundColor = color
            layer.preferredDynamicRange = .high
        } else {
            guard allowsLegacyPath else { throw TriggerError.needsNewerMacOS(26) }
            guard let color = TaggedColor.untaggedCGColor(value: pixel.rawComponent) else {
                throw TriggerError.colorUnavailable
            }
            layer.backgroundColor = color
            layer.wantsExtendedDynamicRangeContent = true   // CALayer's own flag, macOS 14.0–26.0
        }
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

    /// Shows `pixel`: the first call builds the layer and orders the window in, later calls re-colour in place.
    /// Success is the Core Animation commit; false when the colour or the screen is unavailable, or after `remove()`.
    func present(_ pixel: TriggerPixel) async -> Bool {
        guard !isRemoved else { return false }
        do {
            if let layer {
                try commit { try Self.apply(pixel: pixel, headroomTag: headroomTag, to: layer,
                                             allowsLegacyPath: allowsLegacyPath) }
            } else {
                let newLayer = try Self.makeLayer(pixel: pixel, headroomTag: headroomTag,
                                                  allowsLegacyPath: allowsLegacyPath)
                try host.show(layer: newLayer, blend: request.blend)
                layer = newLayer
            }
            shownPixel = pixel
            return true
        } catch {
            log.error("T1 present failed on display \(self.host.display.id): \(String(describing: error), privacy: .public)")
            return false
        }
    }

    /// Static content has no drawable to lose, so this follows the screen geometry and re-commits the colour. If
    /// headroom does not come back, the engine's next step is a re-arm (a new window is a new request).
    func represent() {
        guard !isRemoved, layer != nil else { return }
        host.reposition()
        recolour()
    }

    /// Re-tags in place (tag policy B), no new window. The legacy path has no tag and ignores it.
    func requestHeadroom(_ headroom: Double) {
        guard !isRemoved else { return }
        headroomTag = headroom
        recolour()
    }

    /// Orders the window out and releases the layer. Idempotent.
    func remove() {
        guard !isRemoved else { return }
        isRemoved = true
        host.tearDown()
        layer = nil
        registry?.unregister(self)
    }

    // MARK: RegisteredWindowOwner

    /// Whether the window exists.
    var hasOpenWindow: Bool { host.hasWindow }

    // MARK: Private

    private func recolour() {
        guard let layer, let shownPixel else { return }
        do {
            try commit { try Self.apply(pixel: shownPixel, headroomTag: headroomTag, to: layer,
                                         allowsLegacyPath: allowsLegacyPath) }
        } catch {
            log.error("T1 re-colour failed on display \(self.host.display.id): \(String(describing: error), privacy: .public)")
        }
    }

    private func commit(_ change: () throws -> Void) throws {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        try change()
    }
}
