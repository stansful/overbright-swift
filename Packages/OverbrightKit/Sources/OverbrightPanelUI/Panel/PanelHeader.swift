// OverbrightPanelUI/Panel/PanelHeader.swift — the panel's header: the status symbol in its current state, the name,
// the master switch and the "⋯" menu. DESIGN.md §5.3 (items in order: Dim All Displays / Stop Dimming · Fill Light ✓ ·
// Settings… ⌘, · Run Self-Test… · Help · Quit Overbright ⌘Q; Space or Return on the focused "⋯" opens the same rows,
// §5.12), §12.7 (VoiceOver: the switch is "Overbright").
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

    /// The row's title (title case: menus are AppKit chrome); empty for a separator.
    @MainActor public var title: String {
        switch self {
        case .dimAll(let isDimmed): isDimmed ? MenuTitles.stopDimming : MenuTitles.dimAll
        case .fillLight: MenuTitles.fillLight
        case .separator: ""
        case .settings: MenuTitles.settings
        case .selfTest: MenuTitles.runSelfTest
        case .help: MenuTitles.help
        case .quit: MenuTitles.quit
        }
    }

    /// The row draws a checkmark (Fill Light while on).
    public var isChecked: Bool {
        if case .fillLight(true) = self { return true }
        return false
    }

    /// The ⌘ key equivalent shown on the row ("," for Settings…, "q" for Quit Overbright).
    public var keyEquivalent: String {
        switch self {
        case .settings: ","
        case .quit: "q"
        default: ""
        }
    }
}

/// The header row. It keeps only what it draws from the engine's status (the symbol, the master switch, whether every
/// display is dimmed), so a status change that moves none of them leaves it alone (`Equatable`).
struct PanelHeader: View {
    let symbolState: StatusSymbolState
    let isOn: Bool
    let isEveryDisplayDimmed: Bool
    let fillLightOn: Bool
    let symbol: (StatusSymbolState) -> Image
    let commands: PanelCommands
    let focus: FocusState<PanelFocus?>.Binding
    @Environment(\.panelMenuPresenter) private var menus
    @State private var overflowAnchor = MenuAnchorReference()

    /// The header for `status`.
    init(status: BoostStatus, fillLightOn: Bool, symbol: @escaping (StatusSymbolState) -> Image, commands: PanelCommands,
         focus: FocusState<PanelFocus?>.Binding) {
        symbolState = status.symbol
        isOn = status.isOn
        isEveryDisplayDimmed = DimState.isEveryDisplayDimmed(status)
        self.fillLightOn = fillLightOn
        self.symbol = symbol
        self.commands = commands
        self.focus = focus
    }

    var body: some View {
        HStack(spacing: Space.s) {
            symbol(symbolState)
                .renderingMode(.template)
                .resizable()
                .frame(width: PanelLayout.headerSymbol, height: PanelLayout.headerSymbol)
                .accessibilityHidden(true)
            Text(verbatim: "Overbright")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Space.m)
            Toggle(isOn: Binding(get: { isOn },
                                 set: { commands.services.boost.setOn($0, source: .panel) })) {
                Text(verbatim: "Overbright")
            }
            .toggleStyle(PanelSwitchStyle())                       // accent while on, in a panel that is not key
            .accessibilityLabel(Text(verbatim: "Overbright"))
            .panelFocus(focus, .masterSwitch, cornerRadius: HitTarget.minimum.height / 2) {
                commands.services.boost.setOn(!isOn, source: .panel)
            }
            overflowMenu
        }
        .padding(.horizontal, Space.l)
        .frame(height: PanelLayout.barHeight)
    }

    private var overflowItems: [OverflowItem] {
        OverflowItem.items(isDimmed: isEveryDisplayDimmed, fillLightOn: fillLightOn)
    }

    private var overflowMenu: some View {
        let commands = commands
        return Menu {
            ForEach(Array(overflowItems.enumerated()), id: \.offset) { _, item in
                row(item)
            }
        } label: {
            Image(symbol: .ellipsis)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(IconButtonStyle())
        .fixedSize()
        .background { MenuAnchor(reference: overflowAnchor) }
        .accessibilityLabel(Text(verbatim: PanelText.overflowLabel))
        .panelFocus(focus, .overflow) {
            menus.present(overflowAnchor, KeyboardMenu.items(overflowItems) { Self.perform($0, commands: commands) })
        }
    }

    @ViewBuilder
    private func row(_ item: OverflowItem) -> some View {
        let commands = commands
        switch item {
        case .fillLight(let isOn):
            Toggle(isOn: Binding(get: { isOn }, set: { _ in Self.perform(item, commands: commands) })) {
                Text(verbatim: item.title)
            }
        case .separator:
            Divider()
        default:
            if item.keyEquivalent.isEmpty {
                Button { Self.perform(item, commands: commands) } label: { Text(verbatim: item.title) }
            } else {
                Button { Self.perform(item, commands: commands) } label: { Text(verbatim: item.title) }
                    .keyboardShortcut(KeyEquivalent(Character(item.keyEquivalent)), modifiers: .command)
            }
        }
    }

    /// What a row of the "⋯" menu does (the pointer's menu and the keyboard's run the same).
    static func perform(_ item: OverflowItem, commands: PanelCommands) {
        switch item {
        case .dimAll: commands.services.boost.toggleDim(source: .panel)
        case .fillLight(let isOn): commands.services.fillLight.setOn(!isOn, source: .panel)
        case .separator: break
        case .settings: commands.openSettings(nil)
        case .selfTest: commands.openSettings(SettingsLinks.selfTest)
        case .help: commands.showHelp(nil)
        case .quit: commands.quit()
        }
    }
}

extension PanelHeader: Equatable {
    /// Two headers draw the same when the symbol, the switch, the dimmed state and Fill Light agree; the symbol
    /// drawing, the commands and the focus binding are the panel's own for its life.
    static func == (lhs: PanelHeader, rhs: PanelHeader) -> Bool {
        lhs.symbolState == rhs.symbolState && lhs.isOn == rhs.isOn
            && lhs.isEveryDisplayDimmed == rhs.isEveryDisplayDimmed && lhs.fillLightOn == rhs.fillLightOn
    }
}

#Preview("Header") {
    @Previewable @FocusState var focus: PanelFocus?
    let services = ScriptedStatuses.services(named: "boosting") ?? OverbrightServices.preview()
    PanelHeader(status: services.boost.status, fillLightOn: false, symbol: { _ in Image(symbol: .sunMaxFill) },
                commands: PanelCommands(services: services, source: .panel), focus: $focus)
        .frame(width: PanelLayout.width)
        .overbrightThemeRoot()
}
