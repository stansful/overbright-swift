// OverbrightPolicy/Math/LevelMapping.swift — the slider: level ↔ light gain. ARCHITECTURE.md §3.10, §5.3, D11.
// Real body since WP0a.
import Foundation
import OverbrightCore

/// The slider (D11, §5.3). Boost half linear in stops of `top`; dim half stops = log₂(50) · |p|^2.5.
public nonisolated enum LevelMapping {
    /// Darkest dim level: 2 % of the current SDR light (≈ −5.6 stops).
    public static let minimumDimLight = 0.02
    /// Shape of the dim half: the first half of its travel covers −1 stop, the second half the remaining −4.6.
    public static let dimCurveExponent = 2.5
    /// Light gain the boost half asks for: `top ^ p` for p in 0…1.
    public static func requestedGain(for level: LevelPosition, top: Double) -> Double {
        level.isBoost ? pow(max(top, 1), level.value) : 1
    }
    /// Light factor the dim half asks for: `0.02 ^ (|p| ^ 2.5)` for p in −1…0.
    public static func dimLight(for level: LevelPosition) -> Double {
        level.isDim ? pow(minimumDimLight, pow(-level.value, dimCurveExponent)) : 1
    }
    /// The dim-half position that asks for `light` (clamped to 0.02…1).
    public static func position(forDimLight light: Double) -> LevelPosition {
        let l = min(max(light, minimumDimLight), 1)
        return LevelPosition(-pow(log(l) / log(minimumDimLight), 1 / dimCurveExponent))
    }
    /// The boost-half position that asks for `gain` on a display whose top is `top` (clamped to the top).
    public static func position(forGain gain: Double, top: Double) -> LevelPosition {
        guard top > 1.0001, gain > 1 else { return .standard }
        return LevelPosition(log(min(gain, top)) / log(top))
    }
    /// The nearest preset within ±0.02, for readouts and VoiceOver values.
    public static func preset(at level: LevelPosition) -> LevelPreset? {
        LevelPreset.allCases.first { abs($0.position.value - level.value) <= 0.02 }
    }
}
