// OverbrightSettingsUI/Calibration/CalibrationModel+Step.swift — where the calibration window is and what its results
// say (DESIGN.md §9): the steps `CalibrationModel` moves through and the endings `CalibrationCopy.result(_:)` words.
import Foundation

extension CalibrationModel {
    /// Where the window is.
    public enum Step: Hashable {
        /// No session: the display cannot be calibrated now.
        case unavailable
        /// "Before starting".
        case checklist
        /// Step 1: the comparison and its question.
        case comparison
        /// Step 1 answered No: Compatibility mode, or keep the color table.
        case notBrighter
        /// Step 2, before the sweep starts.
        case sweepIntro
        /// Step 2: the sweep runs (or waits at its pause).
        case sweep
        /// Step 3: the confirmation frame and its question.
        case confirmation
        /// The result.
        case results
    }

    /// What the results say.
    public enum Ending: Hashable {
        /// "Standard curve confirmed."
        case encoded
        /// "This display responds in linear light."
        case linear
        /// "The result wasn't clear, so Overbright keeps its safe default."
        case inconclusive
        /// The screen did not get brighter and the color table was kept.
        case keptColorTable
    }
}
