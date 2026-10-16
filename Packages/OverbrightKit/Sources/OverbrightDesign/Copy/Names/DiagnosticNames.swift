// OverbrightDesign/Copy/Names/DiagnosticNames.swift — the user-facing names of self-test results, other apps and
// calibration records. DESIGN.md §7.4 (Calibration row), §7.8 (Other apps), §10 (self-test results).
import Foundation
import OverbrightCore

public extension SelfTestStrategyResult.Verdict {
    /// "Held" · "Dropped" · "No response" · "Already bright" · "Skipped" (the self-test results table).
    nonisolated func localizedName(in language: CopyLanguage = .app) -> String {
        let (b, l) = (language.bundle, language.locale)
        return switch self {
        case .held: String(localized: "Held", bundle: b, locale: l,
                           comment: "Self-test: result of a method, macOS gave extra range and kept it")
        case .engagedButDropped: String(localized: "Dropped", bundle: b, locale: l,
                                        comment: "Self-test: result of a method, macOS gave extra range, then took it back")
        case .noEngage: String(localized: "No response", bundle: b, locale: l,
                               comment: "Self-test: result of a method, macOS gave no extra range")
        case .invalidBaseline: String(localized: "Already bright", bundle: b, locale: l,
                                      comment: "Self-test: result of a method, something else held extra range when the test began")
        case .skipped: String(localized: "Skipped", bundle: b, locale: l,
                              comment: "Self-test: result of a method that was not tested")
        }
    }
}

public extension ConflictSeverity {
    /// "Brightness app" · "Color app" · "May change brightness" (Settings ▸ Advanced ▸ Other apps); nil for apps that
    /// appear in diagnostics only.
    nonisolated func localizedKind(in language: CopyLanguage = .app) -> String? {
        let (b, l) = (language.bundle, language.locale)
        return switch self {
        case .booster: String(localized: "Brightness app", bundle: b, locale: l,
                              comment: "Settings ▸ Advanced: kind of a running app that also changes display brightness")
        case .gammaWriter: String(localized: "Color app", bundle: b, locale: l,
                                  comment: "Settings ▸ Advanced: kind of a running app that changes display colors")
        case .conditional: String(localized: "May change brightness", bundle: b, locale: l,
                                  comment: "Settings ▸ Advanced: kind of a running app that changes display colors in some modes")
        case .benign: nil
        }
    }
}

/// The value of Settings ▸ Displays ▸ Calibration (DESIGN.md §7.4, §9 "Validity").
public nonisolated enum CalibrationText {
    /// "Not calibrated", "Standard curve (macOS 27.0.1)", "Linear (macOS 27.0.1)" or "Check again: macOS, the preset
    /// or the method changed". `isValid` is false when the record's macOS build, method or potential no longer match;
    /// `osVersion` is the macOS version the record was made on.
    public static func make(_ record: CalibrationRecord?, isValid: Bool, osVersion: String,
                            in language: CopyLanguage = .app) -> String {
        let (b, l) = (language.bundle, language.locale)
        guard let record else { return notCalibrated(in: language) }
        guard isValid else {
            return String(localized: "Check again: macOS, the preset or the method changed", bundle: b, locale: l,
                          comment: "Settings ▸ Displays: Calibration value of a result that no longer applies")
        }
        switch record.outcome {
        case .encoded:
            return String(localized: "Standard curve (macOS \(osVersion))", bundle: b, locale: l,
                          comment: "Settings ▸ Displays: Calibration value; the argument is a macOS version such as 27.0.1")
        case .linear:
            return String(localized: "Linear (macOS \(osVersion))", bundle: b, locale: l,
                          comment: "Settings ▸ Displays: Calibration value of a display that responds in linear light")
        case .inconclusive, .notBrighter:
            return notCalibrated(in: language)
        }
    }

    /// "Not calibrated".
    public static func notCalibrated(in language: CopyLanguage = .app) -> String {
        String(localized: "Not calibrated", bundle: language.bundle, locale: language.locale,
               comment: "Settings ▸ Displays: Calibration value of a display without a valid calibration")
    }
}
