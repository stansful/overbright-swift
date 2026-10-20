// OverbrightOnboarding/Steps/DisplayRowView.swift — one display in Welcome step 2 (DESIGN.md §8: "glyph, name, verdict
// (§12.1), fix button, Use extra brightness switch"), compact so the owner's two or three displays fit the page at once:
// the name line carries the glyph (laptop for the built-in display), the name, the verdict's badge and, at its trailing
// end, the "Use extra brightness" switch of a display that can show it (else the fix button); when they do not fit one
// line (a long name next to a long switch label, as in Russian), the switch goes on its own line under the name rather
// than the name wrapping beside it (`DisplayNameLine`, WP14 C-ONBOARD-1). The verdict's sentence and its advisory lines
// run the full width under it. A display that can boost and also has a fix (a preset that limits it) shows the fix
// under the sentence. The words are the row's `VerdictText` (Design's, for the display's own limit). Built by WP12 from
// PanelUI's `DisplayCardModel` rather than its `DisplayCardView` (the panel's card is a slider card; DESIGN.md §8
// describes a verdict row).
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
            DisplayNameLine(row: row) { trailing }
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
            ExtraBrightnessSwitch(title: switchTitle, isOn: switchBinding)
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

/// Step 2's "Use extra brightness" switch: small, at its natural width.
struct ExtraBrightnessSwitch: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) { Text(verbatim: title) }
            .toggleStyle(.accentSwitch)
            .controlSize(.small)
            .fixedSize()
    }
}

/// A row's name line: the glyph, the name and the verdict's badge, with `trailing` (the switch or the fix) at the end
/// of the line when everything fits it, else on its own line under the name, so the name never wraps beside it.
struct DisplayNameLine<Trailing: View>: View {
    let row: WelcomeDisplayRow
    @ViewBuilder let trailing: Trailing

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Space.s) {
                identity(lineLimit: 1)
                Spacer(minLength: Space.m)
                trailing
            }
            VStack(alignment: .trailing, spacing: Space.xxs) {
                identity(lineLimit: 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                trailing
            }
        }
    }

    /// The glyph (laptop for the built-in display), the name and the badge; a name longer than the row itself wraps.
    private func identity(lineLimit: Int) -> some View {
        HStack(spacing: Space.s) {
            Image(symbol: row.isBuiltIn ? .laptopComputer : .display)
                .font(.title3)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(verbatim: row.name)                                      // DESIGN.md §2.2 `cardTitle`
                .font(.headline)
                .lineLimit(lineLimit)
                .truncationMode(.tail)
                .fixedSize(horizontal: lineLimit == 1, vertical: true)
                .help(row.name)
            if !row.text.badge.isEmpty {
                Text(verbatim: row.text.badge)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
        }
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
