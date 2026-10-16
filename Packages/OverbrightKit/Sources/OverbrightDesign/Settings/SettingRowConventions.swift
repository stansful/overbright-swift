// OverbrightDesign/Settings/SettingRowConventions.swift — the conventions every Settings row shares (Cranny's): the
// changed dot, "Reset to Default" in the row's context menu and as a VoiceOver action, the "changed" hint.
// DESIGN.md §7.2, App. A. Seam written by WP0a (ARCHITECTURE.md §10.0): the modifiers are fixed; WP9 ports Cranny's
// bodies with their strings (Design's catalog). The WP0a body draws the changed dot only.
import OverbrightCore
import SwiftUI

/// Sizes of the Settings row conventions.
public nonisolated enum SettingRowConventions {
    /// The changed-value dot.
    public static let changedDot: CGFloat = 6
    /// Gap between the dot and the row's label (the dot sits in the grouped form's leading inset).
    public static let changedDotGap: CGFloat = 4
}

public extension View {
    /// The row conventions for a row backed by one key.
    func overbrightSettingRow<Value>(_ settings: SettingsStore, _ key: SettingKey<Value>) -> some View {
        overbrightSettingRow(isDefault: settings.isDefault(key), reset: { settings.reset(key) })
    }

    /// The row conventions with explicit "is default" and "reset" (rows backed by several keys or a dictionary entry).
    func overbrightSettingRow(isDefault: Bool, reset: @escaping @MainActor () -> Void) -> some View {
        _ = reset
        return overlay(alignment: Alignment(horizontal: .leading, vertical: .firstTextBaseline)) {
            if !isDefault {
                Circle()
                    .fill(.tint)
                    .frame(width: SettingRowConventions.changedDot, height: SettingRowConventions.changedDot)
                    .offset(x: -(SettingRowConventions.changedDot + SettingRowConventions.changedDotGap))
                    .accessibilityHidden(true)
            }
        }
    }
}
