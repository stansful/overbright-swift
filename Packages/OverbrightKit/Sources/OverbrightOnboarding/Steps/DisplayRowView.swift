// OverbrightOnboarding/Steps/DisplayRowView.swift — one display in Welcome step 2 (DESIGN.md §8, §12.1): the glyph
// (laptop for the built-in display), the name, the verdict's badge and sentence and its advisory lines (Design's
// `VerdictText`, the only producer of verdict copy), the fix button, and "Use extra brightness" for a display that
// can show it. Fix titles come with the verdict text; the panel's titles are the fallback until a verdict has one.
import OverbrightCore
import OverbrightDesign
import OverbrightPanelUI
import SwiftUI

/// A display's row in step 2.
struct DisplayRowView: View {
    let row: WelcomeDisplayRow
    /// "Use extra brightness".
    let switchTitle: String
    let actions: WelcomeDisplayActions

    /// Bumped when the OLED notice was cancelled, so the switch shows "off" again.
    @State private var declined = 0

    var body: some View {
        let text = VerdictText.make(row.verdict, advisories: row.advisories, lastGrant: nil)
        HStack(alignment: .top, spacing: Space.m) {
            Image(symbol: row.isBuiltIn ? .laptopComputer : .display)
                .font(.system(size: StepMetrics.rowGlyph))
                .foregroundStyle(.secondary)
                .frame(width: StepMetrics.rowGlyphColumn)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                    Text(verbatim: row.name)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(row.name)
                    if !text.badge.isEmpty {
                        Text(verbatim: text.badge)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                if !text.sentence.isEmpty {
                    Text(verbatim: text.sentence)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(text.advisories, id: \.self) { line in
                    Text(verbatim: line)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let title = fixTitle(text) {
                    Button { actions.performFix(for: row) } label: { Text(verbatim: title) }
                        .controlSize(.small)
                        .padding(.top, Space.xs)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if row.canBoost {
                Toggle(isOn: switchBinding) { Text(verbatim: switchTitle) }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .fixedSize()
            }
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .stepCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: row.name))
    }

    /// The fix button's title: the verdict's own, else the panel's words for the same destination.
    func fixTitle(_ text: VerdictText) -> String? {
        switch row.fix {
        case .openSystemSettings?: text.fixTitle ?? CardAction.openDisplaySettings.title
        case .choosePeak?: text.fixTitle ?? CardAction.choosePeak.title
        case nil: nil
        }
    }

    private var switchBinding: Binding<Bool> {
        Binding(get: { _ = declined; return row.boostEnabled }, set: { enabled in
            if !actions.setExtraBrightness(enabled, for: row) { declined += 1 }
        })
    }
}

#Preview("Display row") {
    let services = WelcomePreview.services(.russianNames)
    VStack(spacing: Space.s) {
        ForEach(WelcomeDisplayRow.rows(in: services)) { row in
            DisplayRowView(row: row, switchTitle: "Use extra brightness", actions: WelcomeDisplayActions(services: services))
        }
    }
    .padding(Space.xl)
    .frame(width: WelcomeMetrics.window.width)
}
