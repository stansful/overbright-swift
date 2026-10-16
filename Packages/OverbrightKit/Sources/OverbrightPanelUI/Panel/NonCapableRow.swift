// OverbrightPanelUI/Panel/NonCapableRow.swift — displays that can neither be brightened nor dimmed, collapsed into one
// line ("1 display can't be adjusted · Why?") that expands in place into a row per display: name, verdict sentence,
// its fix and "Learn more". DESIGN.md §5.10, §12.1 (the verdict words are Design's), §3.1 (`expand`).
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// The collapsed "can't be adjusted" line and its expansion.
struct NonCapableRow: View {
    let displays: [DisplayStatus]
    let titles: [DisplayKey: String]
    @Binding var isExpanded: Bool
    let commands: PanelCommands
    let focus: FocusState<PanelFocus?>.Binding
    @Environment(\.overbright) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(spacing: Space.xs) {
                Text(verbatim: PanelText.cannotBeAdjusted(displays.count))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(verbatim: "·").foregroundStyle(.secondary).accessibilityHidden(true)
                Button(action: toggle) { Text(verbatim: PanelText.why) }
                    .buttonStyle(OverbrightDesign.LinkButtonStyle())
                    .panelFocus(focus, .why, activate: toggle)
            }
            if isExpanded {
                ForEach(displays, id: \.key) { display in row(display) }
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, Space.xs)
    }

    private func toggle() {
        withAnimation(theme.animation(.expand)) { isExpanded.toggle() }
    }

    @ViewBuilder
    private func row(_ display: DisplayStatus) -> some View {
        let verdict = display.decision?.eligibility.verdict ?? .checking
        let text = VerdictText.make(verdict, advisories: display.decision?.eligibility.advisories ?? [], lastGrant: nil)
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(verbatim: titles[display.key] ?? display.name)
                .font(.headline)
            if !text.sentence.isEmpty {
                Text(verbatim: text.sentence)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: Space.m) {
                if CardChip.verdictFix(verdict) != nil {
                    Button { commands.openSystemSettings(SettingsLinks.systemDisplays) } label: {
                        Text(verbatim: text.fixTitle ?? CardAction.openDisplaySettings.title)
                    }
                    .controlSize(.small)
                    .panelFocus(focus, .fix(display.key)) { commands.openSystemSettings(SettingsLinks.systemDisplays) }
                }
                Button { commands.showHelp(HelpEntry.Anchor.noExtraRange) } label: { Text(verbatim: PanelText.learnMore) }
                    .buttonStyle(OverbrightDesign.LinkButtonStyle())
                    .panelFocus(focus, .learnMore(display.key)) { commands.showHelp(HelpEntry.Anchor.noExtraRange) }
            }
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .quaternarySystemFill), in: RoundedRectangle(cornerRadius: Radius.card,
                                                                                style: .continuous))
        .accessibilityElement(children: .contain)
    }
}
