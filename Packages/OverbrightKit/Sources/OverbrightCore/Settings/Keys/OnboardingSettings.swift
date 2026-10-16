// OverbrightCore/Settings/Keys/OnboardingSettings.swift — Welcome and one-time notices. ARCHITECTURE.md §3.8; DESIGN.md §4.4, §8, §12.4.

/// Welcome and one-time notices.
public nonisolated enum OnboardingSettings {
    /// The app version that finished Welcome; nil = not yet.
    public static let completedVersion = SettingKey(.onboarding, "completedVersion", default: String?.none)
    /// The one-time "Check that it works" calibration tip after the first boost (DESIGN.md §8).
    public static let calibrationTipShown = SettingKey(.onboarding, "calibrationTipShown", default: false)
    /// The app version for which the "icon isn't visible" window was last shown (DESIGN.md §4.4).
    public static let hiddenIconNoticeVersion = SettingKey(.onboarding, "hiddenIconNoticeVersion", default: String?.none)
    /// "Not Now" in the move-to-Applications alert (DESIGN.md §12.4); asked again after an update.
    public static let declinedMoveVersion = SettingKey(.onboarding, "declinedMoveVersion", default: String?.none)
}
