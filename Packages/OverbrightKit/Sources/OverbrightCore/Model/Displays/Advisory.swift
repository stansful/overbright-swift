// OverbrightCore/Model/Displays/Advisory.swift — facts shown next to a verdict. ARCHITECTURE.md §3.2, D8.

/// Facts that change how a supported display behaves, shown next to the verdict.
public nonisolated enum Advisory: String, Codable, Sendable, CaseIterable {
    /// Model/OS where table writes are silently ignored (D4, `CompatibilityModels`).
    case compatibilityModeAdvised
    /// OLED: lower Safe cap, idle pause, black trigger only.
    case oledCare
    /// Built-in XDR on macOS 26+: keep auto-brightness unchanged while boosted.
    case autoBrightnessInteracts
    /// No valid calibration record: readouts are estimates ("≈ ×1.29").
    case notCalibrated
}
