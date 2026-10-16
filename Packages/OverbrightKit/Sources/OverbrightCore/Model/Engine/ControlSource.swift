// OverbrightCore/Model/Engine/ControlSource.swift — who asked for a change. ARCHITECTURE.md §3.5; DESIGN.md §6.

/// Who asked for a change: decides HUD and announcements (DESIGN.md §6).
public nonisolated enum ControlSource: String, Sendable {
    /// The panel.
    case panel
    /// The status menu.
    case menu
    /// A global shortcut.
    case shortcut
    /// An App Intent.
    case intent
    /// The Focus filter.
    case focusFilter
    /// The Welcome window.
    case welcome
    /// The Settings window.
    case settings
    /// A guard or timer.
    case automation
    /// The launch behaviour.
    case launch
    /// A click on the status item (toggle mode).
    case statusItem
}
