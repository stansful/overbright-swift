// OverbrightCore/Fakes/FakeTriggerFactory.swift — a TriggerFactory that opens no window. ARCHITECTURE.md §3.9, §4.3, §4.7.
import CoreGraphics

/// A `TriggerFactory` that records requests, placements and presents, couples to `ScriptedHeadroom` (a successful
/// present makes the script grant headroom), can fail per strategy, can move windows to another screen
/// (`onScreenChange`) and reports `openWindowCount`. It never orders a window in.
@MainActor public final class FakeTriggerFactory: TriggerFactory {
    /// One recorded present.
    public struct Present: Hashable, Sendable {
        /// The display.
        public var display: DisplayKey
        /// The strategy of the trigger.
        public var strategy: TriggerStrategy
        /// The pixel shown.
        public var pixel: TriggerPixel
        /// Whether the present succeeded.
        public var succeeded: Bool
    }
    /// One trigger made.
    public struct Made: Hashable, Sendable {
        /// The request (strategy, pixel, placement, blend, tag).
        public var request: TriggerRequest
        /// The display it was made for.
        public var display: DisplayRef
    }

    /// The headroom script the requests drive (nil: requests move nothing).
    public let headroom: ScriptedHeadroom?
    /// Strategies `isAvailable(_:)` reports.
    public var availableStrategies: Set<TriggerStrategy> = Set(TriggerStrategy.allCases)
    /// `makeTrigger` throws this error for these strategies.
    public var makeErrors: [TriggerStrategy: TriggerError] = [:]
    /// `present` returns false for these strategies (T2/T3 after their 2 s of retries).
    public var failingPresents: Set<TriggerStrategy> = []
    /// Every trigger made, in order.
    public private(set) var made: [Made] = []
    /// Every present, in order.
    public private(set) var presents: [Present] = []
    /// Every trigger handle made (removed ones included).
    public private(set) var triggers: [FakeTriggerHandle] = []
    private var lastID: UInt64 = 0
    /// Keeps only about the newest `recordLimit` entries of `made` and `presents`, of the removed handles in `triggers`
    /// and of each handle's own records (nil, the default: everything). `--qa-simulate` sets one, so a long QA run or
    /// soak does not grow with the fake's own history.
    public var recordLimit: Int? { didSet { trim() } }

    /// A factory; pass the `ScriptedHeadroom` the presents should drive.
    public init(headroom: ScriptedHeadroom? = nil) { self.headroom = headroom }

    // MARK: TriggerFactory

    /// Whether `strategy` is in `availableStrategies`.
    public func isAvailable(_ strategy: TriggerStrategy) -> Bool { availableStrategies.contains(strategy) }

    /// A recorded trigger handle (throws `makeErrors[strategy]`, or `.needsNewerMacOS(26)` when unavailable).
    public func makeTrigger(_ request: TriggerRequest, on display: DisplayRef) throws -> any TriggerHandle {
        guard availableStrategies.contains(request.strategy) else { throw TriggerError.needsNewerMacOS(26) }
        if let error = makeErrors[request.strategy] { throw error }
        lastID += 1
        let handle = FakeTriggerHandle(id: lastID, request: request, display: display, factory: self)
        made.append(Made(request: request, display: display))
        triggers.append(handle)
        trim()
        return handle
    }

    /// Triggers not yet removed.
    public var openWindowCount: Int { triggers.filter { !$0.isRemoved }.count }

    // MARK: Test control

    /// Live triggers on `key`.
    public func liveTriggers(on key: DisplayKey) -> [FakeTriggerHandle] {
        triggers.filter { !$0.isRemoved && $0.display.key == key }
    }
    /// AppKit moved every live window of `key` to the screen of `displayID` (nil: no screen).
    public func moveWindows(on key: DisplayKey, toScreen displayID: CGDirectDisplayID?) {
        for handle in liveTriggers(on: key) { handle.onScreenChange?(displayID) }
    }
    /// The live windows of `key` became occluded or visible.
    public func setOccluded(_ occluded: Bool, on key: DisplayKey) {
        for handle in liveTriggers(on: key) { handle.setOccluded(occluded) }
    }

    // MARK: Handles

    func record(_ present: Present, id: UInt64) {
        presents.append(present)
        trim()
        if present.succeeded { headroom?.requestStarted(id, strategy: present.strategy, on: present.display) }
    }

    func presentSucceeds(_ strategy: TriggerStrategy) -> Bool { !failingPresents.contains(strategy) }

    /// Applies `recordLimit` (amortized: once a record holds twice the limit).
    private func trim() {
        guard let limit = recordLimit.map({ max($0, 1) }) else { return }
        if made.count > 2 * limit { made.removeFirst(made.count - limit) }
        if presents.count > 2 * limit { presents.removeFirst(presents.count - limit) }
        triggers = Self.droppingOldestRemoved(triggers, keep: limit) { $0.isRemoved }
    }

    /// `items` without its oldest removed entries beyond `keep` (live ones always stay), once there are twice `keep`.
    private static func droppingOldestRemoved<T>(_ items: [T], keep: Int, isRemoved: (T) -> Bool) -> [T] {
        var excess = items.filter(isRemoved).count - keep
        guard excess > keep else { return items }
        return items.filter { item in
            guard excess > 0, isRemoved(item) else { return true }
            excess -= 1
            return false
        }
    }

    func requestEnded(_ id: UInt64, on key: DisplayKey) { headroom?.requestEnded(id, on: key) }
}
