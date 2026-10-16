// OverbrightCore/Fakes/FakeTriggerHandle.swift — a trigger "window" made by FakeTriggerFactory. ARCHITECTURE.md §3.9.
import CoreGraphics

/// A trigger "window" that records what the engine asks of it.
@MainActor public final class FakeTriggerHandle: TriggerHandle {
    /// The rung.
    public let request: TriggerRequest
    /// The display it was made for.
    public let display: DisplayRef
    /// Set by `FakeTriggerFactory.setOccluded(_:on:)`.
    public private(set) var isOccluded = false
    /// Called when occlusion changes.
    public var onOcclusionChange: ((Bool) -> Void)?
    /// Called by `FakeTriggerFactory.moveWindows(on:toScreen:)`.
    public var onScreenChange: ((CGDirectDisplayID?) -> Void)?
    /// Pixels presented, in order (failed presents included).
    public private(set) var presentedPixels: [TriggerPixel] = []
    /// Number of `represent()` calls.
    public private(set) var representCount = 0
    /// Every `requestHeadroom(_:)` value.
    public private(set) var requestedHeadroom: [Double] = []
    /// `remove()` was called.
    public private(set) var isRemoved = false
    private let id: UInt64
    private weak var factory: FakeTriggerFactory?

    init(id: UInt64, request: TriggerRequest, display: DisplayRef, factory: FakeTriggerFactory) {
        self.id = id; self.request = request; self.display = display; self.factory = factory
    }

    /// Records the present; succeeds unless the factory fails this strategy (or the handle was removed).
    public func present(_ pixel: TriggerPixel) async -> Bool {
        presentedPixels.append(pixel)
        let succeeded = !isRemoved && (factory?.presentSucceeds(request.strategy) ?? false)
        factory?.record(FakeTriggerFactory.Present(display: display.key, strategy: request.strategy, pixel: pixel,
                                                   succeeded: succeeded), id: id)
        return succeeded
    }
    /// Counts the re-present.
    public func represent() { representCount += 1 }
    /// Records the tag.
    public func requestHeadroom(_ headroom: Double) { requestedHeadroom.append(headroom) }
    /// Ends the request; the window counts as closed.
    public func remove() {
        guard !isRemoved else { return }
        isRemoved = true
        factory?.requestEnded(id, on: display.key)
    }

    func setOccluded(_ occluded: Bool) {
        guard occluded != isOccluded else { return }
        isOccluded = occluded
        onOcclusionChange?(occluded)
    }
}
