// OverbrightCore/Fakes/Fixtures/FixtureTables.swift — profile bases used by the fixtures. ARCHITECTURE.md §3.9, §4.8, D26.
import Foundation

/// Profile bases (the `vcgt` macOS restores) of the fixture displays.
nonisolated enum FixtureTables {
    /// A calibrated profile's base: per-channel curves with a white-point correction (red and blue end below 1, each
    /// channel with its own small gamma tweak), as a calibration loader leaves them. Monotonic, starts at 0.
    static func calibrated(count: Int) -> GammaTable {
        func curve(scale: Double, exponent: Double) -> [Float] {
            (0..<count).map { Float(scale * pow(Double($0) / Double(max(count - 1, 1)), exponent)) }
        }
        return GammaTable(red: curve(scale: 0.985, exponent: 1.02), green: curve(scale: 1.0, exponent: 0.99),
                          blue: curve(scale: 0.96, exponent: 0.98))
    }
}
