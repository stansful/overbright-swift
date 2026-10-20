// OverbrightPolicy/Math/StepMath.swift — keyboard, scroll and Brighter / Less Bright steps, in stops of light.
// ARCHITECTURE.md §3.10, §5.3. Real body since WP0a.
import Foundation
import OverbrightCore

/// Keyboard, scroll and Brighter / Less Bright steps, in stops of light (§5.3).
public nonisolated enum StepMath {
    /// Arrow keys and scroll: 1/12 stop (≈ 6 % light).
    public static let arrowKeyStops = 1.0 / 12
    /// Signed stops of light relative to Standard at `level`.
    public static func stops(at level: LevelPosition, top: Double) -> Double {
        if level.isBoost { return log2(LevelMapping.requestedGain(for: level, top: top)) }
        if level.isDim { return log2(LevelMapping.dimLight(for: level)) }
        return 0
    }
    /// The level that is `s` stops from Standard on a display whose top is `top` (clamped to the slider's ends).
    public static func level(atStops s: Double, top: Double) -> LevelPosition {
        if s > 0 { return top > 1.0001 ? LevelPosition(min(s / log2(top), 1)) : .standard }
        if s < 0 { return LevelMapping.position(forDimLight: pow(2, s)) }
        return .standard
    }
    /// One step; a step that would cross Standard stops at Standard first.
    public static func step(from level: LevelPosition, by delta: Double, top: Double) -> LevelPosition {
        let current = stops(at: level, top: top)
        var next = current + delta
        if (current > 0 && next < 0) || (current < 0 && next > 0) { next = 0 }
        return self.level(atStops: next, top: top)
    }
}
