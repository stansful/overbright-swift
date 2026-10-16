// OverbrightFillLightTests/FillLightStyleTests.swift — value = brightness × min(0.97 × H, 2), else ≤ 1; the headroom
// request (ARCHITECTURE.md §7.6, D5; DESIGN.md §7.7 ranges, §11 "up to 2× white").
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

    @Test func requestAsksForTwiceWhiteAtTheBrightnessWithinThePotential() {
        #expect(style(reading(1)).headroomRequest.map { abs($0 - 1.65) < 1e-9 } == true)
        #expect(style(brightness: 1, reading(1)).headroomRequest.map { abs($0 - 2.07) < 1e-9 } == true)
        #expect(style(brightness: 0.2, reading(1)).headroomRequest.map { abs($0 - 1.01) < 1e-9 } == true)   // ≥ 1.01
        #expect(style(brightness: 1, reading(1, potential: 1.5)).headroomRequest.map { abs($0 - 1.5) < 1e-9 } == true)
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
