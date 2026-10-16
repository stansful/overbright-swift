// OverbrightCore/Settings/Keys/FillLightSettings.swift — Settings ▸ Fill Light. ARCHITECTURE.md §3.8, D12.

/// Settings ▸ Fill Light.
public nonisolated enum FillLightSettings {
    /// nil = the built-in display, else the main display.
    public static let display = SettingKey(.fillLight, "display", default: DisplayKey?.none)
    /// Points, 16…120.
    public static let width = SettingKey(.fillLight, "width", default: 48.0)
    /// 0 = 6500 K (cool) … 1 = 3000 K (warm).
    public static let warmth = SettingKey(.fillLight, "warmth", default: 0.4)
    /// 0.2…1.
    public static let brightness = SettingKey(.fillLight, "brightness", default: 0.8)
    /// Turn on while a camera is in use.
    public static let autoWithCamera = SettingKey(.fillLight, "autoWithCamera", default: false)
    /// Which cameras count.
    public static let cameraFilter = SettingKey(.fillLight, "cameraFilter", default: CameraFilter.anyCamera)
}
