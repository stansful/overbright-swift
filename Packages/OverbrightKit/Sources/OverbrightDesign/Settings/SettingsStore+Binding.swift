// OverbrightDesign/Settings/SettingsStore+Binding.swift — SwiftUI bindings to settings keys. Ported from Cranny's
// SettingsStore (the owner's MIT code); it lives in Design so that Core imports no SwiftUI (D23).
// ARCHITECTURE.md §3.8, §10.0 (Design seam).
import OverbrightCore
import SwiftUI

public extension SettingsStore {
    /// For SwiftUI controls: `Toggle(isOn: settings.binding(GeneralSettings.showsHUD)) { … }`.
    func binding<V>(_ key: SettingKey<V>) -> Binding<V> {
        Binding(get: { self[key] }, set: { self[key] = $0 })
    }
}
