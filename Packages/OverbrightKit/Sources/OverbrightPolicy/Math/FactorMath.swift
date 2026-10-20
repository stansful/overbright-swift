// OverbrightPolicy/Math/FactorMath.swift — light ↔ table-factor conversion per transfer domain. ARCHITECTURE.md §3.10,
// §5.2, D5. Real body since WP0a.
import Foundation
import OverbrightCore

/// Light ↔ table-factor conversion per transfer domain (D5, §5.2). A plain multiply of the baseline is correct under
/// every domain; only the factor chosen for a wanted light gain differs.
public nonisolated enum FactorMath {
    /// sRGB encode, extended above 1 (`1.055·g^(1/2.4) − 0.055`).
    public static func encodeSRGB(_ g: Double) -> Double {
        g <= 0.0031308 ? 12.92 * g : 1.055 * pow(g, 1 / 2.4) - 0.055
    }
    /// sRGB decode, extended above 1.
    public static func decodeSRGB(_ f: Double) -> Double {
        f <= 0.04045 ? f / 12.92 : pow((f + 0.055) / 1.055, 2.4)
    }
    /// Above white, `.encoded` uses this pure power: `F^k ≤ G` for every truth exponent k ≤ 2.4 (incl. the sRGB curve).
    public static let boostExponent = 2.4
    /// The table factor that yields light gain `g` on this display.
    public static func tableFactor(forLightGain g: Double, domain: TransferDomain) -> Double {
        switch domain {
        case .encoded: g <= 1 ? encodeSRGB(g) : pow(g, 1 / boostExponent)
        case .linear: g
        }
    }
    /// The light gain a table factor `f` yields on this display.
    public static func lightGain(forTableFactor f: Double, domain: TransferDomain) -> Double {
        switch domain {
        case .encoded: f <= 1 ? decodeSRGB(f) : pow(f, boostExponent)
        case .linear: f
        }
    }
    /// Writes target at most `headroomMargin × H` …
    public static let headroomMargin = 0.97
    /// … and an applied gain is lowered only when it exceeds `lowerThreshold × H` (≈ 1 % dead band, §5.7).
    public static let lowerThreshold = 0.98
}
