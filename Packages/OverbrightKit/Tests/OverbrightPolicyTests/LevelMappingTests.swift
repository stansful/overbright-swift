// OverbrightPolicyTests/LevelMappingTests.swift — the slider, steps and preset visibility. ARCHITECTURE.md §5.3, §5.6, §9.1.
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

    /// §5.3 "Steps per class": presses of Brighter (¼ stop) and of the arrow keys (1/12 stop) from Standard to the top.
    @Test func stepsPerClass() {
        func presses(top: Double, stops: Double, dim: Bool = false) -> Int {
            var level = LevelPosition.standard
            var count = 0
            while count < 1000 && (dim ? level.value > -1 + 1e-9 : level.value < 1 - 1e-9) {
                level = StepMath.step(from: level, by: dim ? -stops : stops, top: top)
                count += 1
            }
            return count
        }
        let rows: [(top: Double, brighter: Int, arrows: Int)] = [
            (safeM4, 3, 9), (peakM4, 6, 17), (2.0, 4, 12), (1.3, 2, 5), (0.97 * 465.49 / 265.05, 4, 10),
        ]
        for row in rows {
            #expect(presses(top: row.top, stops: StepSize.regular.stops) == row.brighter, "\(row.top)")
            #expect(presses(top: row.top, stops: StepMath.arrowKeyStops) == row.arrows, "\(row.top)")
        }
        #expect(presses(top: safeM4, stops: StepSize.regular.stops, dim: true) == 23)          // dim half: 5.64 stops
        #expect(presses(top: safeM4, stops: StepMath.arrowKeyStops, dim: true) == 68)
    }

    /// No arrow, scroll or Brighter / Less Bright step exceeds ½ stop, and no step crosses Standard.
    @Test func noStepExceedsHalfAStopOrCrossesStandard() {
        var random = SeededGenerator(seed: 0xD1A1)
        for _ in 0..<20_000 {
            let top = Double.random(in: 1.0001...16, using: &random)
            let level = LevelPosition(Double.random(in: -1...1, using: &random))
            let size = [StepSize.regular.stops, StepSize.fine.stops, StepMath.arrowKeyStops].randomElement(using: &random) ?? 0.25
            let delta = Bool.random(using: &random) ? size : -size
            let next = StepMath.step(from: level, by: delta, top: top)
            let moved = abs(StepMath.stops(at: next, top: top) - StepMath.stops(at: level, top: top))
            #expect(moved <= StepMath.maximumSingleStepStops + 1e-9)
            #expect(!(level.isBoost && next.isDim) && !(level.isDim && next.isBoost))
        }
        // A step that would cross Standard stops at Standard first.
        let nearDetent = StepMath.level(atStops: 0.1, top: safeM4)
        #expect(StepMath.step(from: nearDetent, by: -0.25, top: safeM4) == .standard)
        #expect(StepMath.step(from: .standard, by: -0.25, top: safeM4).isDim)
        #expect(StepMath.level(atStops: 3, top: 1) == .standard)                                // no boost half
    }

    /// §5.3 "Presets per class" and D0 note #54 (merging walks down from Max).
    @Test func presetVisibilityPerClass() {
        let all: [LevelPreset] = [.indoor, .brightRoom, .sunlight, .max]
        #expect(PresetVisibility.visiblePresets(top: safeM4) == all)
        #expect(PresetVisibility.visiblePresets(top: peakM4) == all)
        #expect(PresetVisibility.visiblePresets(top: 2.0) == all && PresetVisibility.visiblePresets(top: 3.104) == all)
        #expect(PresetVisibility.visiblePresets(top: 1.940) == all)                             // Studio Display XDR Peak
        #expect(PresetVisibility.visiblePresets(top: 1.3) == [.brightRoom, .max])                // MSI OLED Safe
        #expect(PresetVisibility.visiblePresets(top: 1.704) == all)                              // MSI OLED Peak
        #expect(PresetVisibility.visiblePresets(top: 1.2) == [.max])                             // DisplayHDR 600 at SDR 300
        #expect(PresetVisibility.visiblePresets(top: 1) == [.max])
    }
}
