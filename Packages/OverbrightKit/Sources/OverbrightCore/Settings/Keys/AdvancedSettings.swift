// OverbrightCore/Settings/Keys/AdvancedSettings.swift — Settings ▸ Advanced. ARCHITECTURE.md §3.8, §7.2, §8.3.

/// Settings ▸ Advanced.
public nonisolated enum AdvancedSettings {
    /// `.debug` poll samples in the log.
    public static let detailedLogging = SettingKey(.advanced, "detailedLogging", default: false)
    /// Conflict catalogue entry IDs the user always continues with (S2/S3 only; ARCHITECTURE.md §7.2).
    public static let alwaysContinue = SettingKey(.advanced, "alwaysContinue", default: Set<String>())
}
