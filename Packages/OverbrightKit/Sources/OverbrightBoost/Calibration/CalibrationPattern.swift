// OverbrightBoost/Calibration/CalibrationPattern.swift — the step wedge the calibration window draws, and whose 0.95
// patch the engine's predictions are about. ARCHITECTURE.md §5.2, §5.6; DESIGN.md §9. Pure and nonisolated.

/// The calibration's pattern (DESIGN.md §9: four patches at 85, 90, 95 and 100 % grey on a black surround). One value
/// for both sides: `CalibrationMath` predicts where `mergePatch` merges with white, and the window that shows the
/// sweep draws `patches` on `surround` (`CalibrationController.pattern`), so the two can never disagree.
public nonisolated struct CalibrationPattern: Hashable, Sendable {
    /// The patches, as code values in the screen's colour space, left to right.
    public let patches: [Double]
    /// The surround's code value: black, so an over-bright moment lights only the small patches.
    public let surround: Double
    /// The patch whose merge with white (`patches.last`) the user marks with Space.
    public let mergePatch: Double

    /// The pattern of DESIGN.md §9.
    public static let standard = CalibrationPattern(patches: [0.85, 0.90, 0.95, 1.00], surround: 0, mergePatch: 0.95)
}

extension CalibrationController {
    /// The step wedge every session measures with (the calibration window draws it).
    public nonisolated static var pattern: CalibrationPattern { .standard }
}
