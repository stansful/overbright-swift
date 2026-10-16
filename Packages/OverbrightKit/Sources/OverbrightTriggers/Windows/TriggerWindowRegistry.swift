// OverbrightTriggers/Windows/TriggerWindowRegistry.swift — the factory's list of live triggers and overlays: the
// `triggerWindows` count of diagnostics and smoke (D24, §8.4) and the backstop that removes every window when the
// service stops. ARCHITECTURE.md §3.6 (`openWindowCount`), §7.4 (stop order). Thread: main.
//
// Entries are weak: a handle the engine drops is gone from the count, and its window goes with it (`TriggerHost`
// tears down in its deinit), so no window ever outlives its handle.

/// A trigger or overlay handle as the registry sees it.
protocol RegisteredWindowOwner: AnyObject {
    /// Whether the handle's window exists now.
    var hasOpenWindow: Bool { get }
    /// Orders the window out and releases everything (the handle's own `remove()`).
    func remove()
}

/// Weak list of the handles a factory made.
final class TriggerWindowRegistry {
    private struct Entry {
        weak var owner: (any RegisteredWindowOwner)?
    }

    private var entries: [ObjectIdentifier: Entry] = [:]

    /// Adds `owner` (idempotent).
    func register(_ owner: any RegisteredWindowOwner) {
        prune()
        entries[ObjectIdentifier(owner)] = Entry(owner: owner)
    }

    /// Drops `owner`.
    func unregister(_ owner: any RegisteredWindowOwner) {
        entries[ObjectIdentifier(owner)] = nil
    }

    /// Handles still alive (registered and not removed).
    var liveOwners: [any RegisteredWindowOwner] { entries.values.compactMap(\.owner) }

    /// Windows that exist now.
    var openWindowCount: Int { liveOwners.count(where: \.hasOpenWindow) }

    /// Removes every live handle (each orders its window out).
    func removeAll() {
        let owners = liveOwners
        entries = [:]
        for owner in owners { owner.remove() }
    }

    private func prune() {
        entries = entries.filter { $0.value.owner != nil }
    }
}
