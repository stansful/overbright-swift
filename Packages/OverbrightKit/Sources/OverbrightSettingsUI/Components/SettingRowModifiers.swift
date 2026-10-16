// OverbrightSettingsUI/Components/SettingRowModifiers.swift — the conventions every row with a value shares (DESIGN.md
// §7.2): the search target and highlight (`searchTarget`) plus Design's changed-value dot and Reset to Default in the
// context menu and as a VoiceOver action (`overbrightSettingRow`). Ported from Cranny's SettingRow.swift (the owner's
// MIT code).
import OverbrightCore
import OverbrightDesign
import SwiftUI

extension View {
    /// Row conventions for a row backed by one settings key.
    func settingRow<V>(_ info: SettingsRowInfo, settings: SettingsStore, key: SettingKey<V>) -> some View {
        searchTarget(info).overbrightSettingRow(settings, key)
    }

    /// Row conventions with explicit "is default" and "reset" (rows backed by several keys or a dictionary entry).
    /// Rows with nothing to reset (an action, a state owned by the system) use `searchTarget(_:)` alone.
    func settingRow(_ info: SettingsRowInfo, isDefault: Bool, reset: @escaping @MainActor () -> Void) -> some View {
        searchTarget(info).overbrightSettingRow(isDefault: isDefault, reset: reset)
    }
}
