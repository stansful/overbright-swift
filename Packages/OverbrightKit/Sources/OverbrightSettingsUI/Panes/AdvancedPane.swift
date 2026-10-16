// OverbrightSettingsUI/Panes/AdvancedPane.swift — Settings ▸ Advanced (DESIGN.md §7.8): diagnostics (Copy Diagnostics,
// Run Self-Test… with its sheet, detailed logging), the other apps that change display colors or brightness, the
// trigger method per display with Forget Learned Methods, recovery (Reset Display Colors…, the Force Quit note) and
// Reset All Settings… with Undo Reset (WP0b's `ResetAllRow`). A deep link to "advanced#selfTest" (the panel's and the
// chips' Run Self-Test…) opens the sheet. Seeded empty by WP0b behind the `SettingsPaneView` seam (ARCHITECTURE.md
// §10.2); WP11 owns it (§10.13).
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// Settings ▸ Advanced.
struct AdvancedPane: SettingsPaneView {
    let services: OverbrightServices
    @Environment(SettingsNavigator.self) private var navigator: SettingsNavigator?
    @Environment(ResetAllController.self) private var resetAll: ResetAllController?
    @State private var showsSelfTest = false

    /// The pane for `services`.
    init(services: OverbrightServices) { self.services = services }

    /// The searchable rows.
    static func rows(services: OverbrightServices) -> [SettingsRowInfo] {
        [AdvancedRows.copyDiagnostics, AdvancedRows.selfTest, AdvancedRows.detailedLogging, AdvancedRows.otherApps]
            + TriggerMethodSection.displays(services).map { AdvancedRows.triggerMethod($0.ref.key, name: $0.name) }
            + [AdvancedRows.forgetMethods, AdvancedRows.resetDisplayColors, AdvancedRows.recoveryNote, ResetAllRow.info]
    }

    /// The rows with a value and their Reset to Default.
    static func values(services: OverbrightServices) -> [RowValue] {
        [RowValue(AdvancedRows.detailedLogging, settings: services.settings, key: AdvancedSettings.detailedLogging),
         otherAppsValue(services)]
            + TriggerMethodSection.displays(services).map { TriggerMethodSection.value($0, services: services) }
    }

    /// Rows that show no value of their own (actions and notes).
    static let actionRows: Set<String> = [AdvancedRows.copyDiagnostics.id, AdvancedRows.selfTest.id,
                                          AdvancedRows.forgetMethods.id, AdvancedRows.resetDisplayColors.id,
                                          AdvancedRows.recoveryNote.id, ResetAllRow.info.id]

    /// The other apps: the apps chosen to always continue with.
    static func otherAppsValue(_ services: OverbrightServices) -> RowValue {
        RowValue(AdvancedRows.otherApps, settings: services.settings, key: AdvancedSettings.alwaysContinue)
    }

    /// The row a deep link that opens the self-test sheet points at.
    static var selfTestRowID: String { AdvancedRows.selfTest.id }

    var body: some View {
        SettingsForm(.advanced) {
            Section {
                actionRow(AdvancedRows.copyDiagnostics,
                          footnote: String(localized: "Copies a technical report to the clipboard. Nothing is sent anywhere.",
                                           bundle: .module, comment: "Settings ▸ Advanced: footnote of Copy Diagnostics")) {
                    services.app?.copyDiagnostics()
                }
                actionRow(AdvancedRows.selfTest,
                          footnote: String(localized: "Checks how each display responds. About a minute per display.",
                                           bundle: .module, comment: "Settings ▸ Advanced: footnote of Run Self-Test…")) {
                    showsSelfTest = true
                }
                ToggleRow(info: AdvancedRows.detailedLogging, settings: services.settings, key: AdvancedSettings.detailedLogging,
                          footnote: String(localized: "Adds headroom samples to the system log for troubleshooting.", bundle: .module,
                                           comment: "Settings ▸ Advanced: footnote of Detailed logging (“headroom” is allowed in Advanced)"))
            } header: {
                Text("Diagnostics", bundle: .module, comment: "Settings ▸ Advanced: section header")
            }
            OtherAppsSection(services: services, value: Self.otherAppsValue(services))
            TriggerMethodSection(services: services)
            Section {
                ResetDisplayColorsRow(services: services)
                Text(verbatim: AdvancedRows.recoveryNote.title)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .searchTarget(AdvancedRows.recoveryNote)
            } header: {
                Text("Recovery", bundle: .module, comment: "Settings ▸ Advanced: section header")
            }
            if let resetAll {
                Section {
                    ResetAllRow(controller: resetAll)
                } header: {
                    Text(verbatim: String(localized: "advanced.section.reset", defaultValue: "Reset", bundle: .module,
                                          comment: "Settings ▸ Advanced: section header of Reset All Settings (a noun, not the button)"))
                }
            }
        }
        .sheet(isPresented: $showsSelfTest) {
            SelfTestSheet(services: services) { showsSelfTest = false }
        }
        .onAppear(perform: openSelfTestIfAsked)
        .onChange(of: navigator?.highlightSerial) { openSelfTestIfAsked() }
    }

    /// A push button with its footnote under it.
    private func actionRow(_ info: SettingsRowInfo, footnote: String, action: @escaping @MainActor () -> Void) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Button(action: action) { Text(verbatim: info.title) }
            Text(verbatim: footnote)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .searchTarget(info)
    }

    /// The panel's Run Self-Test… opens Advanced at the self-test row: the sheet opens with it.
    private func openSelfTestIfAsked() {
        guard let navigator, navigator.highlightedRow == Self.selfTestRowID, navigator.isHighlightFresh else { return }
        showsSelfTest = true
    }
}

#Preview("Advanced") {
    let services = OverbrightServices.preview()
    return AdvancedPane(services: services)
        .environment(SettingsNavigator(target: "advanced"))
        .environment(ResetAllController(services: services))
        .frame(width: 650, height: 900)
        .overbrightThemeRoot()
}
