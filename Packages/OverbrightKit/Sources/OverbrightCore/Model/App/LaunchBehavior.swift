// OverbrightCore/Model/App/LaunchBehavior.swift — what happens at login. ARCHITECTURE.md §3.8, D15.

/// What happens at login (Settings ▸ General).
public nonisolated enum LaunchBehavior: String, Codable, Sendable, CaseIterable {
    /// Open at login and turn on.
    case launchAndEnable
    /// Open at login, keep off (default).
    case launchOnly
    /// Not a login item.
    case dontLaunch
}
