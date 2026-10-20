// OverbrightFillLight/Color/ColorTemperature.swift — warmth → kelvin → black-body colour in linear sRGB (pure).
// ARCHITECTURE.md §7.6, §10.9; DESIGN.md §7.7 (Warmth 6,500–3,000 K, default 5,100 K), §11.
import OverbrightCore

/// The Fill Light's colour: a black body between 6 500 K (cool) and 3 000 K (warm), in linear sRGB.
///
/// The chromaticity is the CIE 1931 Planckian locus through the cubic-spline approximation of Kim et al. (2002),
/// which stays within ≈ 5 × 10⁻⁴ of the tabulated locus in this range; it is converted to linear sRGB (D65) with the
/// sRGB primaries and scaled so that the largest component is 1 (the brightest light of that hue without EDR).
public nonisolated enum ColorTemperature {
    /// The cool end of the Warmth slider (warmth 0).
    public static let coolest = 6_500.0
    /// The warm end of the Warmth slider (warmth 1).
    public static let warmest = 3_000.0

    /// The colour temperature of a Warmth value: linear in kelvin, 0 → 6 500 K, 1 → 3 000 K (0.4 → 5 100 K, the
    /// default). Out-of-range values are clamped; a non-finite value is the default warmth's.
    public static func kelvin(warmth: Double) -> Double {
        let w = warmth.isFinite ? min(max(warmth, 0), 1) : FillLightSettings.warmth.defaultValue
        return coolest - (coolest - warmest) * w
    }

    /// CIE 1931 xy of a black body at `kelvin` (clamped to 3 000–6 500 K), Kim et al.'s Planckian-locus spline.
    public static func chromaticity(kelvin: Double) -> (x: Double, y: Double) {
        let t = kelvin.isFinite ? min(max(kelvin, warmest), coolest) : coolest
        let t2 = t * t, t3 = t2 * t
        let x: Double
        if t <= 4_000 {
            x = -0.266_123_9e9 / t3 - 0.234_358_9e6 / t2 + 0.877_695_6e3 / t + 0.179_910
        } else {
            x = -3.025_846_9e9 / t3 + 2.107_037_9e6 / t2 + 0.222_634_7e3 / t + 0.240_390
        }
        let x2 = x * x, x3 = x2 * x
        let y: Double
        if t <= 4_000 {   // the 2 222–4 000 K branch (the 1 667–2 222 K branch lies below this range)
            y = -0.954_947_6 * x3 - 1.374_185_93 * x2 + 2.091_370_15 * x - 0.167_488_67
        } else {
            y = 3.081_758_0 * x3 - 5.873_386_70 * x2 + 3.751_129_97 * x - 0.370_014_83
        }
        return (x, y)
    }

    /// The black-body colour at `kelvin` (clamped to 3 000–6 500 K) in linear sRGB, largest component 1.
    public static func linearSRGB(kelvin: Double) -> LinearRGB {
        let (x, y) = chromaticity(kelvin: kelvin)
        // XYZ with Y = 1, then the sRGB (D65) matrix of IEC 61966-2-1 (Lindbloom's 7-digit form).
        let bigX = x / y, bigY = 1.0, bigZ = (1 - x - y) / y
        let r = 3.240_454_2 * bigX - 1.537_138_5 * bigY - 0.498_531_4 * bigZ
        let g = -0.969_266_0 * bigX + 1.876_010_8 * bigY + 0.041_556_0 * bigZ
        let b = 0.055_643_4 * bigX - 0.204_025_9 * bigY + 1.057_225_2 * bigZ
        let rgb = LinearRGB(red: max(r, 0), green: max(g, 0), blue: max(b, 0))
        let peak = rgb.maximum
        return peak > 0 ? rgb.scaled(by: 1 / peak) : .white
    }

    /// The colour of a Warmth value (`linearSRGB(kelvin: kelvin(warmth:))`).
    public static func linearSRGB(warmth: Double) -> LinearRGB { linearSRGB(kelvin: kelvin(warmth: warmth)) }
}
