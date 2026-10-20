// OverbrightBoostTests/Fakes/OrderCheckingTriggers.swift — a TriggerFactory that checks invariant 2 on every removal.
// ARCHITECTURE.md §4.5 invariant 2 (un-scale before removing a trigger, in every path except display removal).
// Wraps Core's FakeTriggerFactory; opens no window.
import CoreGraphics
import OverbrightCore
@testable import OverbrightBoost

/// Forwards to a `FakeTriggerFactory` and, whenever a trigger is removed, records a violation if its display's live
/// table is still above its base at that moment.
@MainActor final class OrderCheckingTriggers: TriggerFactory {
    let inner: FakeTriggerFactory
    let gamma: FakeGammaPort
    /// "<display id>: <factor>" for every removal while the table was scaled up.
    private(set) var violations: [String] = []
    /// "make:<rung>" and "remove:<rung>" in order ("<strategy>/<pixel>"), for make-before-break checks.
    private(set) var events: [String] = []

    init(inner: FakeTriggerFactory, gamma: FakeGammaPort) { self.inner = inner; self.gamma = gamma }

    func isAvailable(_ strategy: TriggerStrategy) -> Bool { inner.isAvailable(strategy) }

    func makeTrigger(_ request: TriggerRequest, on display: DisplayRef) throws -> any TriggerHandle {
        let handle = CheckedTrigger(inner: try inner.makeTrigger(request, on: display), display: display, owner: self)
        events.append("make:\(Self.name(request))")
        return handle
    }

    static func name(_ request: TriggerRequest) -> String { "\(request.strategy.rawValue)/\(request.pixel.rawValue)" }

    var openWindowCount: Int { inner.openWindowCount }

    /// The removal check: the display's table must not be above its base.
    fileprivate func removing(on display: DisplayRef, request: TriggerRequest) {
        events.append("remove:\(Self.name(request))")
        guard let table = gamma.table(of: display.id), let base = gamma.base(of: display.id) else { return }
        let above = zip(table.channels, base.channels).contains { t, b in zip(t, b).contains { $0 > $1 + 1e-6 } }
        if above { violations.append("\(display.id): table above base") }
    }
}

@MainActor private final class CheckedTrigger: TriggerHandle {
    let inner: any TriggerHandle
    let display: DisplayRef
    weak var owner: OrderCheckingTriggers?
    private var removed = false

    init(inner: any TriggerHandle, display: DisplayRef, owner: OrderCheckingTriggers) {
        self.inner = inner; self.display = display; self.owner = owner
    }

    var request: TriggerRequest { inner.request }
    var isOccluded: Bool { inner.isOccluded }
    var onOcclusionChange: ((Bool) -> Void)? {
        get { inner.onOcclusionChange }
        set { inner.onOcclusionChange = newValue }
    }
    var onScreenChange: ((CGDirectDisplayID?) -> Void)? {
        get { inner.onScreenChange }
        set { inner.onScreenChange = newValue }
    }
    func present(_ pixel: TriggerPixel) async -> Bool { await inner.present(pixel) }
    func represent() { inner.represent() }
    func requestHeadroom(_ headroom: Double) { inner.requestHeadroom(headroom) }
    func remove() {
        if !removed { owner?.removing(on: display, request: inner.request) }
        removed = true
        inner.remove()
    }
}
