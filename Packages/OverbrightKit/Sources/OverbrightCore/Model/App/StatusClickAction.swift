// OverbrightCore/Model/App/StatusClickAction.swift — what a click on the status item does. ARCHITECTURE.md §3.8, D13.

/// What a left click on the status item does.
public nonisolated enum StatusClickAction: String, Codable, Sendable, CaseIterable {
    /// Default: click = panel, right/Control-click = menu.
    case openPanel
    /// Click = on/off, right/Control-click = menu (which then starts with "Show Panel").
    case toggle
}
