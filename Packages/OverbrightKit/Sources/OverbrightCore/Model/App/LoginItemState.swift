// OverbrightCore/Model/App/LoginItemState.swift — the login item's state (ported from Cranny). ARCHITECTURE.md §3.6.

/// `SMAppService.mainApp` as Settings ▸ General shows it.
public nonisolated enum LoginItemState: Hashable, Sendable {
    /// Registered and allowed.
    case enabled
    /// Not registered.
    case disabled
    /// Registered, waiting for approval in System Settings ▸ Login Items.
    case requiresApproval
    /// The service cannot be used (e.g. a translocated copy).
    case unavailable
}
