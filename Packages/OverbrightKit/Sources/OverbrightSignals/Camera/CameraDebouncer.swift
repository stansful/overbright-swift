// OverbrightSignals/Camera/CameraDebouncer.swift — "a camera is in use", debounced 1 s on / 3 s off. ARCHITECTURE.md
// §7.1 ("Camera in use"), D12, DESIGN.md §11 (the Fill Light comes on 1 s after a camera starts and goes off 3 s after
// the last one stops). Apps open and close the camera briefly while they switch devices; without the debounce the Fill
// Light would flash.
// Thread: any (a value type, owned by the main-actor `CameraMonitor`).
import OverbrightCore

/// Publishes a raw "in use" reading only after it has held for the on or off delay.
nonisolated struct CameraDebouncer: Sendable {
    /// A raw "in use" must hold this long to publish true.
    static let onDelay: Duration = .seconds(1)
    /// A raw "not in use" must hold this long to publish false.
    static let offDelay: Duration = .seconds(3)

    /// The debounced value (`SystemSnapshot.isCameraInUse`).
    private(set) var published = false
    /// The last raw reading.
    private(set) var raw = false
    private var rawSince = MonotonicInstant(sinceOrigin: .zero)

    /// Nothing in use.
    init() {}

    /// When the pending raw value would publish; nil when the raw value equals the published one.
    var pendingDeadline: MonotonicInstant? {
        raw == published ? nil : rawSince + (raw ? Self.onDelay : Self.offDelay)
    }

    /// Records a raw reading taken at `now` (a repeated value keeps its original start) and returns the pending
    /// deadline.
    @discardableResult mutating func observe(_ inUse: Bool, at now: MonotonicInstant) -> MonotonicInstant? {
        if inUse != raw { raw = inUse; rawSince = now }
        return pendingDeadline
    }

    /// Publishes the raw value if it has held until `now`; true when `published` changed.
    mutating func resolve(at now: MonotonicInstant) -> Bool {
        guard let deadline = pendingDeadline, now >= deadline else { return false }
        published = raw
        return true
    }
}
