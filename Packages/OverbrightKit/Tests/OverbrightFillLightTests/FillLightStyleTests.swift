// OverbrightFillLightTests/FillLightStyleTests.swift — value = brightness × min(0.97 × H, 2), else ≤ 1; the headroom
// request and the steady state it leads to (ARCHITECTURE.md §7.6, §4.7, D5; DESIGN.md §7.7 ranges, §11 "up to 2×
// white").
import OverbrightCore
import Testing
@testable import OverbrightFillLight

private func reading(_ current: Double, potential: Double = 16) -> HeadroomReading {
    HeadroomReading(display: 1, current: current, potential: potential, reference: 0,
                    time: MonotonicInstant(sinceOrigin: .zero))
}

private func style(brightness: Double = 0.8, _ reading: HeadroomReading?,
                   rendering: FillLightRendering = .taggedLayer) -> FillLightStyle {
    FillLightStyle.make(width: 48, warmth: 0.4, brightness: brightness, reading: reading, rendering: rendering,
                        reachesTop: false)
}

@Suite struct FillLightStyleTests {
    @Test func edrValueScalesBrightnessByTheUsableGrant() {
        #expect(abs(style(reading(1.0)).value - 0.8) < 1e-9)            // nothing granted yet: SDR white
        #expect(abs(style(reading(1.5)).value - 1.16) < 1e-9)           // 0.8 × 1.455, rounded down
        #expect(abs(style(reading(2.667)).value - 1.6) < 1e-9)          // capped at 2× white
        #expect(abs(style(brightness: 1, reading(4)).value - 2) < 1e-9)
        #expect(abs(style(brightness: 0.2, reading(4)).value - 0.4) < 1e-9)
    }

    @Test func requestAsksForTheHeadroomTheFormulaUsesInFullWithinThePotential() {
        // 2 ÷ 0.97 = 2.062, rounded up, whatever the Brightness: the tag never caps what the formula needs.
        for brightness in [0.2, 0.5, 0.8, 1] {
            #expect(style(brightness: brightness, reading(1)).headroomRequest.map { abs($0 - 2.07) < 1e-9 } == true)
            #expect(style(brightness: brightness, reading(3)).headroomRequest.map { abs($0 - 2.07) < 1e-9 } == true)
        }
        #expect(style(brightness: 1, reading(1, potential: 1.5)).headroomRequest.map { abs($0 - 1.5) < 1e-9 } == true)
        #expect(style(reading(1, potential: 1.015)).headroomRequest.map { abs($0 - 1.02) < 1e-9 } == true)
        let full = FillLightStyle.fullGainHeadroom * FillLightStyle.headroomMargin
        #expect(abs(full - FillLightStyle.maximumGain) < 1e-12)
    }

    @Test func grantingTheOwnRequestSettlesAtTwiceTheBrightness() {
        // §4.7 policy B's case: macOS grants about what the tag asks. The light then reaches 2 × brightness, so the
        // Brightness slider is linear (20 % → 0.4 … 100 % → 2.0), not quadratic.
        for step in 4...20 {
            let brightness = Double(step) * 0.05
            let request = style(brightness: brightness, reading(1)).headroomRequest ?? 0
            let settled = style(brightness: brightness, reading(request))
            #expect(abs(settled.value - 2 * brightness) < 1e-9, "brightness \(brightness): \(settled.value)")
            #expect(settled.headroomRequest == request)                          // stable: the same tag again
            #expect(settled.displayedColor.maximum <= request + 1e-12)           // the colour stays within its tag
        }
        #expect(abs(style(brightness: 0.8, reading(2.07)).value - 1.6) < 1e-9)
    }

    @Test func moreHeadroomThanTheRequestChangesNothing() {
        // Boost's trigger or an HDR video raises H past the request: the light stays where the request put it.
        let settled = style(reading(2.07))
        for current in [2.2, 3.2, 4.6, 16] {
            let raised = style(reading(current))
            #expect(raised.value == settled.value, "H \(current)")
            #expect(raised.headroomRequest == settled.headroomRequest)
        }
    }

    @Test func aLimitedPotentialKeepsTheSliderProportional() {
        // A display whose potential is below 2.07: the request is the potential and the value follows the grant.
        let half = style(brightness: 0.5, reading(1.5, potential: 1.5))
        let full = style(brightness: 1, reading(1.5, potential: 1.5))
        #expect(abs(half.value - 0.72) < 1e-9)                                  // 0.5 × 1.455, rounded down
        #expect(abs(full.value - 1.45) < 1e-9)
        #expect(full.displayedColor.maximum <= 0.97 * 1.5)
    }

    @Test func noExtraRangeMeansSDRAndNoRequest() {
        for s in [style(reading(1, potential: 1)), style(nil), style(reading(2.5), rendering: .sdr)] {
            #expect(s.headroomRequest == nil)
            #expect(abs(s.value - 0.8) < 1e-9)
            #expect(s.displayedColor.maximum <= 1)
        }
    }

    @Test func brightnessIsClampedToItsRange() {
        #expect(abs(style(brightness: 0, nil).value - 0.2) < 1e-9)
        #expect(abs(style(brightness: 3, nil).value - 1) < 1e-9)
        #expect(abs(style(brightness: .nan, nil).value - 0.8) < 1e-9)
    }

    @Test func nonFiniteHeadroomFallsBackToWhite() {
        #expect(abs(style(reading(.nan)).value - 0.8) < 1e-9)
    }

    @Test func colourComesFromTheWarmthAndValueNeverPassesTheMargin() {
        for current in stride(from: 1.0, through: 4.0, by: 0.01) {
            let s = style(brightness: 1, reading(current))
            #expect(s.color == ColorTemperature.linearSRGB(warmth: 0.4))
            #expect(s.displayedColor.maximum <= max(0.97 * current, 1) + 1e-12, "H \(current)")
        }
    }
}
