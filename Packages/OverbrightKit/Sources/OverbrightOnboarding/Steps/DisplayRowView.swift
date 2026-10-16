// OverbrightOnboarding/Steps/DisplayRowView.swift — one display in Welcome step 2 (DESIGN.md §8: "glyph, name, verdict
// (§12.1), fix button, Use extra brightness switch"), compact so the owner's two or three displays fit the page at once:
// the name line carries the glyph (laptop for the built-in display), the name, the verdict's badge and, at its trailing
// end, the "Use extra brightness" switch of a display that can show it (else the fix button); the verdict's sentence
// and its advisory lines run the full width under it. A display that can boost and also has a fix (a preset that
// limits it) shows the fix under the sentence. The words are the row's `VerdictText` (Design's, for the display's own
// limit). Built by WP12 from PanelUI's `DisplayCardModel` rather than its `DisplayCardView` (the panel's card is a
// slider card; DESIGN.md §8 describes a verdict row).
import OverbrightCore
import OverbrightDesign
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
        let text = row.text
        VStack(alignment: .leading, spacing: Space.xxs) {
            HStack(spacing: Space.s) {
                Image(symbol: row.isBuiltIn ? .laptopComputer : .display)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(verbatim: row.name)                                  // DESIGN.md §2.2 `cardTitle`
                    .font(.headline)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                    .help(row.name)
                if !text.badge.isEmpty {
                    Text(verbatim: text.badge)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
                Spacer(minLength: Space.m)
                trailing
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
            if row.canBoost { fixButton.padding(.top, Space.xxs) }
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .stepCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: row.name))
    }

    /// The name line's trailing control: the switch of a display that can boost, else the fix.
    @ViewBuilder private var trailing: some View {
        if row.canBoost {
            Toggle(isOn: switchBinding) { Text(verbatim: switchTitle) }
                .toggleStyle(.switch)
                .controlSize(.small)
                .fixedSize()
        } else {
            fixButton
        }
    }

    /// The verdict's fix button (its title comes with the verdict's words), if it has one.
    @ViewBuilder private var fixButton: some View {
        if row.fix != nil, let title = row.text.fixTitle {
            Button { actions.performFix(for: row) } label: { Text(verbatim: title) }
                .controlSize(.small)
                .fixedSize()
        }
    }

    private var switchBinding: Binding<Bool> {
        Binding(get: { _ = declined; return row.boostEnabled }, set: { enabled in
            if !actions.setExtraBrightness(enabled, for: row) { declined += 1 }
        })
    }
}

#Preview("Display rows") {
    let services = WelcomePreview.threeDisplays
    let actions = WelcomeDisplayActions(services: services, choices: WelcomeChoices())
    VStack(spacing: Space.s) {
        ForEach(WelcomeDisplayRow.rows(in: services)) { row in
            DisplayRowView(row: row, switchTitle: "Use extra brightness", actions: actions)
        }
    }
    .padding(WelcomeMetrics.inset)
    .frame(width: WelcomeMetrics.window.width)
    .overbrightThemeRoot()
}

#Preview("Display row · HDR off") {
    let services = WelcomePreview.services(.mpg322uxHDROff)
    let actions = WelcomeDisplayActions(services: services, choices: WelcomeChoices())
    VStack(spacing: Space.s) {
        ForEach(WelcomeDisplayRow.rows(in: services)) { row in
            DisplayRowView(row: row, switchTitle: "Use extra brightness", actions: actions)
        }
    }
    .padding(WelcomeMetrics.inset)
    .frame(width: WelcomeMetrics.window.width)
    .overbrightThemeRoot()
}
