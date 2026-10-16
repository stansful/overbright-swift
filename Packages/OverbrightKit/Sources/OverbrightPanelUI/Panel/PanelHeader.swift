// OverbrightPanelUI/Panel/PanelHeader.swift — the panel's header: the status symbol in its current state, the name,
// the master switch and the "⋯" menu. DESIGN.md §5.3 (items in order: Dim All Displays / Stop Dimming · Fill Light ✓ ·
// Settings… ⌘, · Run Self-Test… · Help · Quit Overbright ⌘Q), §12.7 (VoiceOver: the switch is "Overbright").
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// One row of the "⋯" menu.
public nonisolated enum OverflowItem: Hashable, Sendable {
    /// Dim All Displays, or Stop Dimming while every display is dimmed.
    case dimAll(isDimmed: Bool)
    /// Fill Light, checked while on.
    case fillLight(isOn: Bool)
    /// A separator.
    case separator
    /// Settings… ⌘,
    case settings
    /// Run Self-Test…
    case selfTest
    /// Help
    case help
    /// Quit Overbright ⌘Q
    case quit

    /// The rows of the "⋯" menu.
    public static func items(isDimmed: Bool, fillLightOn: Bool) -> [OverflowItem] {
        [.dimAll(isDimmed: isDimmed), .fillLight(isOn: fillLightOn), .separator, .settings, .selfTest, .help, .separator,
         .quit]
    }
}

/// The header row.
struct PanelHeader: View {
    let status: BoostStatus
    let fillLightOn: Bool
    let symbol: (StatusSymbolState) -> Image
    let commands: PanelCommands
    let focus: FocusState<PanelFocus?>.Binding

    var body: some View {
        HStack(spacing: Space.s) {
            symbol(status.symbol)
                .renderingMode(.template)
                .resizable()
                .frame(width: PanelLayout.headerSymbol, height: PanelLayout.headerSymbol)
                .accessibilityHidden(true)
            Text(verbatim: "Overbright")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Space.m)
            Toggle(isOn: Binding(get: { status.isOn },
                                 set: { commands.services.boost.setOn($0, source: .panel) })) {
                Text(verbatim: "Overbright")
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()
            .accessibilityLabel(Text(verbatim: "Overbright"))
            .panelFocus(focus, .masterSwitch, cornerRadius: HitTarget.minimum.height / 2) {
                commands.services.boost.setOn(!status.isOn, source: .panel)
            }
            overflowMenu
        }
        .padding(.horizontal, Space.l)
        .frame(height: PanelLayout.barHeight)
    }

    private var overflowMenu: some View {
        Menu {
            ForEach(Array(OverflowItem.items(isDimmed: DimState.isEveryDisplayDimmed(status), fillLightOn: fillLightOn)
                .enumerated()), id: \.offset) { _, item in
                row(item)
            }
        } label: {
            Image(symbol: .ellipsis)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(IconButtonStyle())
        .fixedSize()
        .accessibilityLabel(Text(verbatim: PanelText.overflowLabel))
        .panelFocus(focus, .overflow)
    }

    @ViewBuilder
    private func row(_ item: OverflowItem) -> some View {
        switch item {
        case .dimAll(let isDimmed):
            Button { commands.services.boost.toggleDim(source: .panel) } label: {
                Text(verbatim: isDimmed ? MenuTitles.stopDimming : MenuTitles.dimAll)
            }
        case .fillLight(let isOn):
            Toggle(isOn: Binding(get: { isOn }, set: { commands.services.fillLight.setOn($0, source: .panel) })) {
                Text(verbatim: MenuTitles.fillLight)
            }
        case .separator:
            Divider()
        case .settings:
            Button { commands.openSettings(nil) } label: { Text(verbatim: MenuTitles.settings) }
                .keyboardShortcut(",", modifiers: .command)
        case .selfTest:
            Button { commands.openSettings(SettingsLinks.selfTest) } label: { Text(verbatim: MenuTitles.runSelfTest) }
        case .help:
            Button { commands.showHelp(nil) } label: { Text(verbatim: MenuTitles.help) }
        case .quit:
            Button { commands.quit() } label: { Text(verbatim: MenuTitles.quit) }
                .keyboardShortcut("q", modifiers: .command)
        }
    }
}
