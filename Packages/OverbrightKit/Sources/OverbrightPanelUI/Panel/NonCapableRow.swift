// OverbrightPanelUI/Panel/NonCapableRow.swift — displays that can neither be brightened nor dimmed, collapsed into one
// line ("1 display can't be adjusted · Why?") that expands in place into a row per display: name, verdict sentence,
// its fix and "Learn more". DESIGN.md §5.10, §12.1 (the verdict words are Design's), §3.1 (`expand`). The line keeps
// its leading place whether collapsed or expanded; each row is one of the panel's cards (`panelCard`).
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
                    .buttonStyle(OverbrightLinkButtonStyle())
                    .panelFocus(focus, .why, activate: toggle)
            }
            .padding(.horizontal, Space.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            if isExpanded {
                ForEach(displays, id: \.key) { display in row(display) }
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    .buttonStyle(OverbrightLinkButtonStyle())
                    .panelFocus(focus, .learnMore(display.key)) { commands.showHelp(HelpEntry.Anchor.noExtraRange) }
            }
        }
        .panelCard()
        .accessibilityElement(children: .contain)
    }
}

#Preview("Why? · expanded") {
    @Previewable @State var isExpanded = true
    @Previewable @FocusState var focus: PanelFocus?
    let services = ScriptedStatuses.services(named: "why-expanded") ?? OverbrightServices.preview()
    let status = services.boost.status
    NonCapableRow(displays: status.displays.filter(PanelContent.isNonCapable), titles: CardTitles.titles(for: status.displays),
                  isExpanded: $isExpanded, commands: PanelCommands(services: services, source: .panel), focus: $focus)
        .padding(PanelLayout.outerPadding)
        .frame(width: PanelLayout.width)
        .overbrightThemeRoot()
}
