// OverbrightCore/Model/App/MenuBarIconVisibility.swift — the status-item visibility check. ARCHITECTURE.md §3.6; DESIGN.md §4.4.

/// Result of the status-item visibility check (DESIGN.md §4.4), run 3 s after launch and on every screen change.
public nonisolated enum MenuBarIconVisibility: Hashable, Sendable {
    /// The icon can be seen.
    case visible
    /// General ▸ Show menu bar icon is off.
    case hiddenByUser
    /// No window, not visible, occluded, or behind the notch.
    case notVisible
}
