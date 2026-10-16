// OverbrightCore/Settings/Keys/SettingsNamespace.swift — namespaces of the settings keys. ARCHITECTURE.md §3.8.
// Every key lives in Core because almost all are shared (UI writes, Boost/Signals read). Never rename a key after a
// release; a changed default needs a SettingsUpgrades step.

/// Namespaces (Cranny's `ModuleID` idea). The stored key is "overbright.<namespace>.<name>".
public nonisolated enum SettingsNamespace: String, Sendable, CaseIterable {
    /// Settings ▸ General.
    case general
    /// Settings ▸ Displays and the per-display preferences.
    case displays
    /// Settings ▸ Automations.
    case automations
    /// Settings ▸ Shortcuts.
    case shortcuts
    /// Settings ▸ Fill Light (stored as "filllight").
    case fillLight = "filllight"
    /// Settings ▸ Advanced.
    case advanced
    /// Welcome and one-time notices.
    case onboarding
    /// The update check.
    case updates
    /// Engine records (not preferences; excluded from Reset All by the caller).
    case engine
}
