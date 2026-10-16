// OverbrightPolicy/Math/PresetVisibility.swift — which presets a display shows. ARCHITECTURE.md §3.10, §5.3.
// Real body since WP0a.
import Foundation
import OverbrightCore

/// Which presets a display shows (§5.3): Max always; a lower preset only if its gain is ≥ ×1.1 and it sits ≥ 0.1 stop
/// below the next kept one. Hidden presets are neither drawn nor offered in menus or to VoiceOver.
public nonisolated enum PresetVisibility {
    /// The smallest gain a shown preset may have.
    public static let minimumGain = 1.1
    /// The smallest distance, in stops, between two shown presets.
    public static let minimumSpacingStops = 0.1
    /// The presets shown on a display whose top is `top`, lowest first, always ending with Max.
    public static func visiblePresets(top: Double) -> [LevelPreset] {
        var kept: [LevelPreset] = [.max]
        var lastGain = max(top, 1)
        for preset in [LevelPreset.sunlight, .brightRoom, .indoor] {
            let g = LevelMapping.requestedGain(for: preset.position, top: top)
            if g >= minimumGain && log2(lastGain / g) >= minimumSpacingStops {
                kept.insert(preset, at: 0); lastGain = g
            }
        }
        return kept
    }
}
