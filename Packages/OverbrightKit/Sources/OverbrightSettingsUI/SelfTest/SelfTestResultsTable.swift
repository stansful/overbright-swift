// OverbrightSettingsUI/SelfTest/SelfTestResultsTable.swift — one display's results (DESIGN.md §10): Method · Result
// (Held / Dropped / No response / Already bright / Skipped) · Response time · Steady time, one row per rung measured.
// Each row reads as one VoiceOver element.
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// The results table of one display.
struct SelfTestResultsTable: View {
    let results: [SelfTestStrategyResult]

    /// The cells of one result, in column order.
    static func cells(_ result: SelfTestStrategyResult) -> [String] {
        [result.strategy.localizedName(pixel: result.pixel), result.verdict.localizedName(),
         SelfTestText.time(result.secondsToFirstMovement), SelfTestText.time(result.secondsToStable)]
    }

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: Space.xl, verticalSpacing: Space.xs) {
            GridRow {
                ForEach([SelfTestText.methodColumn, SelfTestText.resultColumn, SelfTestText.responseColumn,
                         SelfTestText.steadyColumn], id: \.self) { header in
                    Text(verbatim: header).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
            .accessibilityHidden(true)
            ForEach(Array(results.enumerated()), id: \.offset) { _, result in
                let cells = Self.cells(result)
                GridRow {
                    ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                        Text(verbatim: cell)
                            .monospacedDigit()
                            .gridColumnAlignment(index >= 2 ? .trailing : .leading)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: cells.dropFirst().reduce(cells[0]) { CopyFormat.spokenParts($0, $1) }))
            }
        }
    }
}
