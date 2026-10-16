// OverbrightFillLightTests/ColorTemperatureTests.swift — CCT → linear sRGB against the CIE 1931 Planckian locus
// (ARCHITECTURE.md §10.9 acceptance: "the CCT function matches reference values within 1 %"; DESIGN.md §7.7).
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightFillLight

/// Reference chromaticities of the black body (CIE 1931 2° observer, the tabulated Planckian locus).
private nonisolated let planckianLocus: [(kelvin: Double, x: Double, y: Double)] = [
    (3_000, 0.436_95, 0.404_10),
    (4_000, 0.380_52, 0.376_73),
    (5_000, 0.345_11, 0.351_61),
    (6_500, 0.313_52, 0.323_63),
]

/// xy → linear sRGB (D65, IEC 61966-2-1's 4-digit matrix), largest component 1: written independently of the
/// implementation (different matrix precision, no shared code), so a wrong matrix, branch or normalisation fails.
private func referenceRGB(x: Double, y: Double) -> [Double] {
    let bigX = x / y, bigZ = (1 - x - y) / y
    let rgb = [3.2406 * bigX - 1.5372 - 0.4986 * bigZ,
               -0.9689 * bigX + 1.8758 + 0.0415 * bigZ,
               0.0557 * bigX - 0.2040 + 1.0570 * bigZ]
    let peak = rgb.max() ?? 1
    return rgb.map { $0 / peak }
}

private func components(_ rgb: LinearRGB) -> [Double] { [rgb.red, rgb.green, rgb.blue] }

@Suite struct ColorTemperatureTests {
    @Test(arguments: planckianLocus.indices)
    func linearSRGBMatchesTheBlackBodyWithinOnePercent(_ index: Int) {
        let reference = planckianLocus[index]
        let expected = referenceRGB(x: reference.x, y: reference.y)
        let actual = components(ColorTemperature.linearSRGB(kelvin: reference.kelvin))
        for (a, e) in zip(actual, expected) {
            #expect(abs(a - e) <= 0.01 * e, "\(reference.kelvin) K: \(actual) vs \(expected)")
        }
    }

    @Test(arguments: planckianLocus.indices)
    func chromaticityFollowsTheTabulatedLocus(_ index: Int) {
        let reference = planckianLocus[index]
        let (x, y) = ColorTemperature.chromaticity(kelvin: reference.kelvin)
        #expect(abs(x - reference.x) < 5e-4 && abs(y - reference.y) < 5e-4, "\(reference.kelvin) K: (\(x), \(y))")
    }

    @Test func knownColoursAtTheEnds() {
        // 3 000 K is clearly orange (green about half of red, blue about a sixth); 6 500 K is nearly white.
        let warm = ColorTemperature.linearSRGB(kelvin: 3_000)
        #expect(warm.red == 1)
        #expect(abs(warm.green - 0.477) < 0.005 && abs(warm.blue - 0.154) < 0.003)
        let cool = ColorTemperature.linearSRGB(kelvin: 6_500)
        #expect(cool.red == 1 && cool.green > 0.93 && cool.blue > 0.98)
    }

    @Test func warmthMapsLinearlyInKelvin() {
        #expect(ColorTemperature.kelvin(warmth: 0) == 6_500)
        #expect(ColorTemperature.kelvin(warmth: 1) == 3_000)
        #expect(abs(ColorTemperature.kelvin(warmth: 0.4) - 5_100) < 1e-9)          // DESIGN.md §7.7: 5,100 K
        #expect(abs(ColorTemperature.kelvin(warmth: FillLightSettings.warmth.defaultValue) - 5_100) < 1e-9)
        #expect(ColorTemperature.kelvin(warmth: -3) == 6_500)
        #expect(ColorTemperature.kelvin(warmth: 7) == 3_000)
        #expect(abs(ColorTemperature.kelvin(warmth: .nan) - 5_100) < 1e-9)
        for warmth in stride(from: 0.0, through: 1.0, by: 0.05) {
            #expect(abs(ColorTemperature.warmth(kelvin: ColorTemperature.kelvin(warmth: warmth)) - warmth) < 1e-12)
        }
    }

    @Test func kelvinOutsideTheRangeIsClamped() {
        #expect(ColorTemperature.linearSRGB(kelvin: 1_900) == ColorTemperature.linearSRGB(kelvin: 3_000))
        #expect(ColorTemperature.linearSRGB(kelvin: 10_000) == ColorTemperature.linearSRGB(kelvin: 6_500))
        #expect(ColorTemperature.linearSRGB(kelvin: .infinity) == ColorTemperature.linearSRGB(kelvin: 6_500))
    }

    @Test func warmerIsRedderAtEveryStepAndTheBrightestComponentIsOne() {
        var previous: LinearRGB?
        for kelvin in stride(from: 3_000.0, through: 6_500.0, by: 50) {
            let rgb = ColorTemperature.linearSRGB(kelvin: kelvin)
            #expect(abs(rgb.maximum - 1) < 1e-12)
            #expect(min(rgb.red, rgb.green, rgb.blue) > 0)
            if let previous {
                // Cooler: more green and more blue relative to red (the 4 000 K spline seam included).
                #expect(rgb.blue / rgb.red > previous.blue / previous.red, "\(kelvin) K")
                #expect(rgb.green / rgb.red > previous.green / previous.red, "\(kelvin) K")
            }
            previous = rgb
        }
    }

    @Test func warmthAndKelvinEntryPointsAgree() {
        #expect(ColorTemperature.linearSRGB(warmth: 0.4) == ColorTemperature.linearSRGB(kelvin: 5_100))
        #expect(ColorTemperature.linearSRGB(warmth: 1) == ColorTemperature.linearSRGB(kelvin: 3_000))
    }
}
