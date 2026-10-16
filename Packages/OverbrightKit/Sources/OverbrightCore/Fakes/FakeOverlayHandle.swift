// OverbrightCore/Fakes/FakeOverlayHandle.swift — an overlay "window" made by FakeTriggerFactory. ARCHITECTURE.md §3.9, §7.5.
import CoreGraphics

/// A Compatibility-mode overlay "window" that records its factors.
@MainActor public final class FakeOverlayHandle: OverlayHandle {
    /// The display it was made for.
    public let display: DisplayRef
    /// Set by `FakeTriggerFactory.setOccluded(_:on:)`.
    public private(set) var isOccluded = false
    /// Called when occlusion changes.
    public var onOcclusionChange: ((Bool) -> Void)?
    /// Called by `FakeTriggerFactory.moveWindows(on:toScreen:)`.
    public var onScreenChange: ((CGDirectDisplayID?) -> Void)?
    /// Every `setFactor` call as (factor, headroom request).
    public private(set) var factors: [(factor: Double, headroomRequest: Double)] = []
    /// Number of `represent()` calls.
    public private(set) var representCount = 0
    /// `remove()` was called.
    public private(set) var isRemoved = false
    /// The next `setFactor` throws this error when set.
    public var nextError: TriggerError?
    private let id: UInt64
    private weak var factory: FakeTriggerFactory?

    init(id: UInt64, display: DisplayRef, factory: FakeTriggerFactory) {
        self.id = id; self.display = display; self.factory = factory
    }

    /// The factor shown now (1 before the first call).
    public var factor: Double { factors.last?.factor ?? 1 }

    /// Records the factor; a factor of at least 1 that asks for more than SDR (`max(factor, request) > 1`) is an EDR
    /// request the script answers, exactly as the real `CompatibilityOverlay` (request first, then boost, §7.5).
    public func setFactor(_ factor: Double, headroomRequest: Double) throws {
        if let error = nextError { nextError = nil; throw error }
        factors.append((factor, headroomRequest))
        if factor >= 1 && max(factor, headroomRequest) > 1 {
            factory?.requestStarted(id, on: display.key)
        } else {
            factory?.requestEnded(id, on: display.key)
        }
    }
    /// Counts the re-present.
    public func represent() { representCount += 1 }
    /// Ends any request; the overlay counts as closed.
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
