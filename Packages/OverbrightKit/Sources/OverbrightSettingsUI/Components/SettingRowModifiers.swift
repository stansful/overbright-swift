// OverbrightSettingsUI/Components/SettingRowModifiers.swift — the conventions every row with a value shares (DESIGN.md
// §7.2): the search target and highlight (`searchTarget`) plus Design's changed-value dot and Reset to Default in the
// context menu and as a VoiceOver action (`overbrightSettingRow`). Ported from Cranny's SettingRow.swift (the owner's
// MIT code). A rendered row also reports itself to a `SettingRowAudit` when the environment holds one (tests only), so
// a test can check that every value row a pane shows carries Reset to Default, and that it resets that row.
import OverbrightCore
import OverbrightDesign
import SwiftUI

extension View {
    /// Row conventions for a row backed by one settings key.
    func settingRow<V>(_ info: SettingsRowInfo, settings: SettingsStore, key: SettingKey<V>) -> some View {
        settingRow(info, isDefault: settings.isDefault(key), reset: { settings.reset(key) })
    }

    /// Row conventions with explicit "is default" and "reset" (rows backed by several keys or a dictionary entry).
    /// Rows with nothing to reset (an action, a state owned by the system) use `searchTarget(_:)` alone.
    func settingRow(_ info: SettingsRowInfo, isDefault: Bool, reset: @escaping @MainActor () -> Void) -> some View {
        searchTarget(info)
            .overbrightSettingRow(isDefault: isDefault, reset: reset)
            .modifier(SettingRowAuditing(id: info.id, reset: reset))
    }
}

/// The rows a rendered pane gave Reset to Default, with the reset each one runs (tests put one in the environment;
/// the app never does).
final class SettingRowAudit {
    /// Row id → the reset of its "Reset to Default".
    private(set) var resets: [String: @MainActor () -> Void] = [:]

    /// Row `id` was rendered with Reset to Default.
    func record(_ id: String, reset: @escaping @MainActor () -> Void) { resets[id] = reset }
}

extension EnvironmentValues {
    /// Where rendered rows report their Reset to Default (nil in the app).
    @Entry var settingRowAudit: SettingRowAudit?
}

/// Reports a row to the environment's audit while it renders.
private struct SettingRowAuditing: ViewModifier {
    let id: String
    let reset: @MainActor () -> Void

    func body(content: Content) -> some View {
        content.background { SettingRowAuditProbe(id: id, reset: reset) }
    }
}

/// An empty background that reports its row: a view body runs whenever the row is laid out.
private struct SettingRowAuditProbe: View {
    @Environment(\.settingRowAudit) private var audit
    let id: String
    let reset: @MainActor () -> Void

    var body: some View {
        let _ = audit?.record(id, reset: reset)                            // a plain object: no view update
        Color.clear.accessibilityHidden(true)
    }
}

#Preview("Row conventions") {
    let services = OverbrightServices.preview()
    Form {
        Toggle(isOn: services.settings.binding(GeneralSettings.haptics)) { Text(verbatim: "Haptic feedback") }
            .settingRow(SettingsRowInfo(.general, "haptics", title: "Haptic feedback"), settings: services.settings,
                        key: GeneralSettings.haptics)
    }
    .formStyle(.grouped)
    .frame(width: 420, height: 120)
}
