// OverbrightTriggers/Windows/RegisteredWindowOwner.swift — a trigger or overlay handle as `TriggerWindowRegistry`
// sees it. ARCHITECTURE.md §3.6 (`openWindowCount`), §7.4 (stop order). Thread: main.

/// A trigger or overlay handle as the registry sees it.
protocol RegisteredWindowOwner: AnyObject {
    /// Whether the handle's window exists now.
    var hasOpenWindow: Bool { get }
    /// Orders the window out and releases everything (the handle's own `remove()`).
    func remove()
}
