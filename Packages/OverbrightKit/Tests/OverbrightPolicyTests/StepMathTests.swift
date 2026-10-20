// OverbrightPolicyTests/StepMathTests.swift — keyboard, scroll and Brighter / Less Bright steps in stops of light.
// ARCHITECTURE.md §5.3 ("Steps per class"), §9.1 (no step exceeds ½ stop).
import Foundation
import OverbrightCore
import OverbrightTestSupport
import Testing
@testable import OverbrightPolicy

@Suite struct StepMathTests {
    private func top(_ fixture: DisplayFixture, _ mode: CapMode, oled: Bool = false) -> Double {
        GainCeiling.sliderTop(facts: fixture.displays[0].facts, capMode: mode, isOLED: oled)
    }
    /// Presses from Standard to the end of a half.
    private func presses(top: Double, stops: Double, dim: Bool = false) -> Int {
        var level = LevelPosition.standard
        var count = 0
        while count < 1000 && (dim ? level.value > -1 + 1e-9 : level.value < 1 - 1e-9) {
            level = StepMath.step(from: level, by: dim ? -stops : stops, top: top)
            count += 1
        }
        return count
    }

    /// §5.3 "Steps per class": span in stops, Brighter presses (¼ stop) and arrow presses (1/12 stop), with the tops
    /// the classes really get from `GainCeiling.sliderTop`.
    @Test func stepsPerClass() {
        let rows: [(name: String, top: Double, span: Double, brighter: Int, arrows: Int)] = [
            ("M4 Max Safe", top(.builtinXDRLidOpen, .safe), 0.74, 3, 9),
            ("M4 Max Peak", top(.builtinXDRLidOpen, .peak), 1.37, 6, 17),
            ("Pro Display XDR Safe", top(.proDisplayXDR, .safe), 1.00, 4, 12),
            ("MSI OLED Safe", top(.mpg322uxHDROn, .safe, oled: true), 0.38, 2, 5),
            ("MSI OLED Peak", top(.mpg322uxHDROn, .peak, oled: true), 0.77, 4, 10),
        ]
        for row in rows {
            #expect(abs(log2(row.top) - row.span) < 0.005, "\(row.name): \(log2(row.top)) stops")
            #expect(presses(top: row.top, stops: StepSize.regular.stops) == row.brighter, "\(row.name)")
            #expect(presses(top: row.top, stops: StepMath.arrowKeyStops) == row.arrows, "\(row.name)")
        }
        // The dim half spans 5.64 stops on every display: 23 Less Bright presses, 68 arrow presses.
        #expect(abs(-StepMath.stops(at: LevelPosition(-1), top: 2) - 5.64) < 0.005)
        for display in rows.map(\.top) {
            #expect(presses(top: display, stops: StepSize.regular.stops, dim: true) == 23)
            #expect(presses(top: display, stops: StepMath.arrowKeyStops, dim: true) == 68)
        }
    }

    /// Steps are in stops: ¼ stop ≈ 19 % light, 1/12 stop ≈ 6 %, the same on every display (DESIGN.md §5.5).
    @Test func aStepIsTheSameLightOnEveryDisplay() {
        for top in [1.3, 1.667, 2.587, 3.104] {
            let one = StepMath.step(from: .standard, by: StepSize.regular.stops, top: top)
            #expect(abs(LevelMapping.requestedGain(for: one, top: top) - pow(2, 0.25)) < 1e-9)
            let fine = StepMath.step(from: .standard, by: StepSize.fine.stops, top: top)
            #expect(abs(LevelMapping.requestedGain(for: fine, top: top) - pow(2, 1.0 / 12)) < 1e-9)
        }
        #expect(abs(pow(2, StepSize.regular.stops) - 1.19) < 0.005 && abs(pow(2, StepMath.arrowKeyStops) - 1.06) < 0.005)
    }

    /// No arrow, scroll or Brighter / Less Bright step exceeds ½ stop, and no step crosses Standard (§9.1).
    @Test func noStepExceedsHalfAStopOrCrossesStandard() {
        var random = SeededGenerator(seed: 0xD1A1)
        for _ in 0..<20_000 {
            let top = Double.random(in: 1.0001...16, using: &random)
            let level = LevelPosition(Double.random(in: -1...1, using: &random))
            let size = [StepSize.regular.stops, StepSize.fine.stops, StepMath.arrowKeyStops].randomElement(using: &random) ?? 0.25
            let delta = Bool.random(using: &random) ? size : -size
            let next = StepMath.step(from: level, by: delta, top: top)
            let moved = abs(StepMath.stops(at: next, top: top) - StepMath.stops(at: level, top: top))
            #expect(moved <= 0.5 + 1e-9)                                     // named-stop jumps excluded
            #expect(!(level.isBoost && next.isDim) && !(level.isDim && next.isBoost))
        }
        // A step that would cross Standard stops at Standard first; the next press continues past it.
        let safeM4 = top(.builtinXDRLidOpen, .safe)
        let nearDetent = StepMath.level(atStops: 0.1, top: safeM4)
        #expect(StepMath.step(from: nearDetent, by: -0.25, top: safeM4) == .standard)
        #expect(StepMath.step(from: .standard, by: -0.25, top: safeM4).isDim)
        #expect(StepMath.step(from: StepMath.level(atStops: -0.1, top: safeM4), by: 0.25, top: safeM4) == .standard)
        #expect(StepMath.level(atStops: 3, top: 1) == .standard)                                // no boost half
        #expect(StepMath.level(atStops: 9, top: safeM4) == LevelPosition(1))                    // clamped to Max
        #expect(StepMath.level(atStops: -9, top: safeM4) == LevelPosition(-1))                  // clamped to the floor
    }
}
