// OverbrightCore/Settings/Keys/UpdateSettings.swift — the update check. ARCHITECTURE.md §3.8, D2.
import Foundation

/// The update check (inert while the repository key is empty).
public nonisolated enum UpdateSettings {
    /// Check daily.
    public static let automatic = SettingKey(.updates, "automatic", default: false)
    /// Include pre-releases.
    public static let prereleases = SettingKey(.updates, "prereleases", default: false)
    /// When the last check ran.
    public static let lastCheck = SettingKey(.updates, "lastCheck", default: Date?.none)
}
