// OverbrightCore/Model/Engine/ExtraBrightnessRequest.swift — a boost-half request. ARCHITECTURE.md §3.5; DESIGN.md §12.8.

/// What an intent or the menu asks for on the boost half (DESIGN.md §12.8).
public nonisolated enum ExtraBrightnessRequest: Hashable, Sendable {
    /// A named preset.
    case preset(LevelPreset)
    /// A light multiplier, clamped to each display's own ceiling.
    case multiplier(Double)
}
