// OverbrightSettingsUITests/SettingsSegmentFitTests.swift — the segmented controls of Settings fit their row
// (ARCHITECTURE.md §8.8 width rule `segment`, DESIGN.md §16): Safe / Peak (and Regular / Fine) stay segments in English
// and in the pseudo-long locale (+40 %), measured as the control draws them (Russian and every language are WP15's;
// a choice row whose segments do not fit becomes a pop-up, `ChoiceRow`).
import AppKit
import OverbrightCore
import OverbrightDesign
import SwiftUI
import Testing
@testable import OverbrightSettingsUI

@MainActor @Suite struct SettingsSegmentFitTests {
    /// A row at the window's minimum size: the detail column (780 − the widest sidebar, 260) less the grouped form's
    /// insets and the row's own padding.
    static let rowWidth = SettingsMetrics.minimumWindowSize.width - SettingsMetrics.sidebarWidth.max - 2 * Space.xxl - 2 * Space.l
    /// A two-segment control may take half of it; the label and its footnote keep the other half.
    static let segmentBudget = rowWidth / 2

    private func segments(_ labels: [String]) -> some View {
        Picker(selection: .constant(0)) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in Text(verbatim: label).tag(index) }
        } label: {
            Text(verbatim: "")
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .fixedSize()
    }

    private var english: CopyLanguage { .english() }

    @Test func safeAndPeakFitInEnglishAndThePseudoLongLocale() {
        let labels = CapMode.allCases.map { $0.localizedName(in: english) }
        #expect(labels.count == 2 && !labels.contains(LevelPreset.max.localizedName(in: english)))   // never “Max”
        let width = FitMeasure.idealWidth(segments(labels))
        let longer = FitMeasure.idealWidth(segments(labels.map(PseudoLocale.lengthen)))
        #expect(width > 40 && width <= Self.segmentBudget, "Safe / Peak \(width) pt")
        #expect(longer > width && longer <= Self.segmentBudget, "pseudo-long Safe / Peak \(longer) pt")
    }

    @Test func regularAndFineFitInEnglishAndThePseudoLongLocale() {
        let labels = StepSize.allCases.map { $0.localizedName(in: english) }
        #expect(FitMeasure.idealWidth(segments(labels)) <= Self.segmentBudget)
        #expect(FitMeasure.idealWidth(segments(labels.map(PseudoLocale.lengthen))) <= Self.segmentBudget)
    }
}
