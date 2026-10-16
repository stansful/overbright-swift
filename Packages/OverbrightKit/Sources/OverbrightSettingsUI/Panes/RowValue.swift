// OverbrightSettingsUI/Panes/RowValue.swift — what "Reset to Default" means for one row with a value (DESIGN.md §7.2:
// "every row with a value has Reset to Default in its context menu"). Each pane lists its value rows once
// (`values(services:)`); the row's view applies the same entry (`settingRow(_:)`), and the tests change and reset
// every entry, so a row that shows a value cannot lack its reset.
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// One row with a value: whether it is at its default, and how to return it there.
struct RowValue {
    /// The row (its id is the scroll target and deep link).
    let info: SettingsRowInfo
    /// The value equals its default (no changed dot; "Reset to Default" disabled).
    let isDefault: @MainActor () -> Bool
    /// Returns the value to its default.
    let reset: @MainActor () -> Void

    /// A row backed by one settings key.
    init<V>(_ info: SettingsRowInfo, settings: SettingsStore, key: SettingKey<V>) {
        self.info = info
        isDefault = { settings.isDefault(key) }
        reset = { settings.reset(key) }
    }

    /// A row backed by something else (a dictionary entry, a port, several keys).
    init(_ info: SettingsRowInfo, isDefault: @escaping @MainActor () -> Bool, reset: @escaping @MainActor () -> Void) {
        self.info = info
        self.isDefault = isDefault
        self.reset = reset
    }
}

extension View {
    /// The row conventions of `value`: scroll target, search highlight, changed dot and Reset to Default.
    func settingRow(_ value: RowValue) -> some View {
        settingRow(value.info, isDefault: value.isDefault(), reset: value.reset)
    }
}
