// OverbrightPolicyTests/LevelMappingTests.swift — the slider: level ↔ light gain, the dim half and the named dim stops.
// ARCHITECTURE.md §5.3, §5.6, §9.1. Steps: StepMathTests; ticks: PresetVisibilityTests.
import Foundation
import OverbrightCore
import OverbrightTestSupport
import Testing
@testable import OverbrightPolicy

@Suite struct LevelMappingTests {
    private let safeM4 = 1000.0 / 600                                // 1.667
    private let peakM4 = 0.97 * 1600 / 600                           // 2.587

    /// §5.6: preset gains (G → F) for the M4 Max built-in indoors.
    @Test func presetGainsOfTheM4MaxBuiltIn() {
        let expected: [(LevelPreset, safe: Double, safeF: Double, peak: Double, peakF: Double)] = [
            (.indoor, 1.136, 1.055, 1.268, 1.104), (.brightRoom, 1.291, 1.112, 1.608, 1.219),
            (.sunlight, 1.467, 1.173, 2.040, 1.346), (.max, 1.667, 1.237, 2.587, 1.486),
        ]
        for (preset, safe, safeF, peak, peakF) in expected {
            let gs = LevelMapping.requestedGain(for: preset.position, top: safeM4)
            let gp = LevelMapping.requestedGain(for: preset.position, top: peakM4)
            #expect(abs(gs - safe) < 0.0006 && abs(gp - peak) < 0.0006, "\(preset)")
            #expect(abs(FactorMath.tableFactor(forLightGain: gs, domain: .encoded) - safeF) < 0.0006, "\(preset)")
            #expect(abs(FactorMath.tableFactor(forLightGain: gp, domain: .encoded) - peakF) < 0.0006, "\(preset)")
        }
        #expect(LevelMapping.requestedGain(for: .standard, top: safeM4) == 1)
        #expect(LevelMapping.requestedGain(for: LevelPosition(-0.5), top: safeM4) == 1)
        #expect(LevelMapping.requestedGain(for: LevelPreset.max.position, top: 0.8) == 1)    // a top below 1 boosts nothing
    }

    /// §5.6: the dim half (−0.25 → 0.885, −0.5 → 0.501, −0.75 → 0.149, −1 → 0.020) and its factors.
    @Test func theDimHalf() {
        for (p, light, factor) in [(-0.25, 0.885, 0.948), (-0.5, 0.501, 0.736), (-0.75, 0.149, 0.422), (-1.0, 0.020, 0.152)] {
            let l = LevelMapping.dimLight(for: LevelPosition(p))
            #expect(abs(l - light) < 0.0006, "\(p)")
            #expect(abs(FactorMath.tableFactor(forLightGain: l, domain: .encoded) - factor) < 0.0006, "\(p)")
        }
        #expect(LevelMapping.dimLight(for: .standard) == 1 && LevelMapping.dimLight(for: LevelPosition(0.5)) == 1)
        // The first half of the travel covers −1 stop.
        #expect(abs(log2(LevelMapping.dimLight(for: LevelPosition(-0.5))) - -1) < 0.003)
    }

    /// §5.3: named dim stops 50 %, 25 %, 10 %, 5 %, 2 % sit at −0.500, −0.660, −0.809, −0.899, −1.
    @Test func namedDimStops() {
        for (light, position) in [(0.5, -0.500), (0.25, -0.660), (0.10, -0.809), (0.05, -0.899), (0.02, -1.0)] {
            #expect(abs(LevelMapping.position(forDimLight: light).value - position) < 0.0006, "\(light)")
        }
        #expect(LevelMapping.position(forDimLight: 0.001) == LevelPosition(-1))                // clamped to the floor
        #expect(LevelMapping.position(forDimLight: 1) == .standard)
    }

    @Test func positionsInvertTheMapping() {
        var random = SeededGenerator(seed: 7)
        for _ in 0..<2000 {
            let p = LevelPosition(Double.random(in: -1...1, using: &random))
            let top = Double.random(in: 1.05...16, using: &random)
            let back = p.isDim ? LevelMapping.position(forDimLight: LevelMapping.dimLight(for: p))
                               : LevelMapping.position(forGain: LevelMapping.requestedGain(for: p, top: top), top: top)
            #expect(abs(back.value - p.value) < 1e-9)
        }
        #expect(LevelMapping.position(forGain: 9, top: 2) == LevelPosition(1))                 // clamped to the top
        #expect(LevelMapping.position(forGain: 2, top: 1) == .standard)                       // no boost half
        #expect(LevelMapping.preset(at: LevelPosition(0.51)) == .brightRoom)
        #expect(LevelMapping.preset(at: LevelPosition(0.6)) == nil && LevelMapping.preset(at: .standard) == .standard)
    }
}
