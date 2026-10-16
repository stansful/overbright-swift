// OverbrightDesign/Settings/SettingRowConventions.swift — the conventions every Settings row shares (Cranny's): a
// 6-pt accent dot before a changed value, "Reset to Default" in the row's context menu and as a VoiceOver action, and a
// VoiceOver hint that the value was changed. DESIGN.md §7.2, App. A. Seam written by WP0a (ARCHITECTURE.md §10.0): the
// modifiers are fixed; ported from Cranny's SettingRowConventions.swift (the owner's MIT code) with its strings in
// Design's catalog.
import Foundation
import OverbrightCore
import SwiftUI

/// Sizes of the Settings row conventions.
public nonisolated enum SettingRowConventions {
    /// The changed-value dot.
    public static let changedDot: CGFloat = 6
    /// Gap between the dot and the row's label (the dot sits in the grouped form's leading inset).
    public static let changedDotGap: CGFloat = 4

    /// "Reset to Default": the row's context-menu item and VoiceOver action.
    public static func resetToDefault(in language: CopyLanguage = .app) -> String {
        String(localized: "Reset to Default", bundle: language.bundle, locale: language.locale,
               comment: "Settings: row context menu item and VoiceOver action")
    }

    /// "Changed from the default": the VoiceOver hint of a changed row and the dot's help tag.
    public static func changed(in language: CopyLanguage = .app) -> String {
        String(localized: "Changed from the default", bundle: language.bundle, locale: language.locale,
               comment: "Settings: VoiceOver hint of a row whose value differs from its default, and the tooltip of its dot")
    }
}

public extension View {
    /// The row conventions for a row backed by one key.
    func overbrightSettingRow<Value>(_ settings: SettingsStore, _ key: SettingKey<Value>) -> some View {
        overbrightSettingRow(isDefault: settings.isDefault(key), reset: { settings.reset(key) })
    }

    /// The row conventions with explicit "is default" and "reset" (rows backed by several keys or a dictionary entry).
    func overbrightSettingRow(isDefault: Bool, reset: @escaping @MainActor () -> Void) -> some View {
        overbrightChangedDot(!isDefault).overbrightResetToDefault(isDefault: isDefault, reset: reset)
    }

    /// The 6-pt accent dot just before the view's first line of text, outside its frame (in the form's leading inset),
    /// while `isChanged`. Decorative: VoiceOver hears the hint of `overbrightResetToDefault` instead.
    func overbrightChangedDot(_ isChanged: Bool) -> some View {
        overlay(alignment: Alignment(horizontal: .leading, vertical: .firstTextBaseline)) {
            if isChanged {
                Circle()
                    .fill(.tint)
                    .frame(width: SettingRowConventions.changedDot, height: SettingRowConventions.changedDot)
                    .offset(x: -(SettingRowConventions.changedDot + SettingRowConventions.changedDotGap))
                    .accessibilityHidden(true)
                    .help(SettingRowConventions.changed())
            }
        }
    }

    /// "Reset to Default" in the row's context menu (disabled at the default) and as a VoiceOver action (offered only
    /// when there is something to reset), plus the hint "Changed from the default" while it differs.
    func overbrightResetToDefault(isDefault: Bool, reset: @escaping @MainActor () -> Void) -> some View {
        overbrightResetToDefault(isDefault: isDefault, reset: reset) { EmptyView() }
    }

    /// `overbrightResetToDefault(isDefault:reset:)` with the row's own context-menu items above "Reset to Default".
    func overbrightResetToDefault<Menu: View>(isDefault: Bool, reset: @escaping @MainActor () -> Void,
                                              @ViewBuilder menu: () -> Menu) -> some View {
        modifier(ResetToDefaultModifier(isDefault: isDefault, reset: reset, menu: menu()))
    }
}

struct ResetToDefaultModifier<Menu: View>: ViewModifier {
    let isDefault: Bool
    let reset: @MainActor () -> Void
    let menu: Menu

    func body(content: Content) -> some View {
        content
            .contextMenu {
                if Menu.self != EmptyView.self {
                    menu
                    Divider()
                }
                Button(SettingRowConventions.resetToDefault(), action: reset)
                    .disabled(isDefault)
            }
            .accessibilityActions {
                if !isDefault {
                    Button(SettingRowConventions.resetToDefault(), action: reset)
                }
            }
            .accessibilityHint(Text(verbatim: isDefault ? "" : SettingRowConventions.changed()))
    }
}

#Preview("Setting rows") {
    let settings = OverbrightServices.preview().settings
    settings[GeneralSettings.haptics] = false
    return Form {
        Toggle(isOn: settings.binding(GeneralSettings.haptics)) { Text(verbatim: "Haptic feedback (changed)") }
            .overbrightSettingRow(settings, GeneralSettings.haptics)
        Toggle(isOn: settings.binding(GeneralSettings.showsHUD)) { Text(verbatim: "Show level changes (default)") }
            .overbrightSettingRow(settings, GeneralSettings.showsHUD)
    }
    .formStyle(.grouped)
    .frame(width: 480, height: 160)
    .overbrightThemeRoot()
}
