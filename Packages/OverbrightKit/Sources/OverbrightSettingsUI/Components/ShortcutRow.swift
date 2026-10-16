// OverbrightSettingsUI/Components/ShortcutRow.swift — one shortcut row of Settings ▸ Shortcuts (DESIGN.md §7.6): the
// label, the recorder, and a conflict line in place: "Another app already uses this shortcut." (registration failed),
// "Already used for Brighter." (another Overbright shortcut) or "macOS uses this for ‹name›." (an enabled macOS
// shortcut, best effort, `SystemShortcuts`). Bindings go through `ShortcutCenter.set`, which stores them and
// re-registers at once; "Reset to Default" removes the override. Clearing Back to Standard asks first. Ported from
// Cranny's ShortcutRecorder.swift (the owner's MIT code) onto Core's `ShortcutCenter` port.
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// A recorder row for one global shortcut.
struct ShortcutRow: View {
    /// The row (its title is the shortcut's name).
    let info: SettingsRowInfo
    /// The catalog entry.
    let shortcut: GlobalShortcut
    let services: OverbrightServices
    /// The names of the other shortcuts, for "Already used for …".
    let names: [ShortcutID: String]
    /// The enabled macOS shortcuts.
    let system: [SystemShortcut]
    var footnote: String?
    @State private var confirmingClear = false

    var body: some View {
        let settings = services.settings
        let combo = Self.effectiveCombo(shortcut, settings: settings)
        let isDefault = settings[ShortcutSettings.bindings][shortcut.id] == nil
        LabeledContent {
            ShortcutRecorder(title: info.title, keys: keys(for: combo),
                             listening: { services.shortcuts.setRecording($0) },
                             announce: { services.announcer.announce($0, kind: .feedback) }) { recorded in
                if recorded == nil, shortcut.id == .standard {
                    confirmingClear = true
                } else {
                    services.shortcuts.set(shortcut.id, recorded)
                }
            }
        } label: {
            RowLabel(title: info.title, footnote: warning(for: combo) ?? footnote)
        }
        .settingRow(info, isDefault: isDefault) {
            settings[ShortcutSettings.bindings][shortcut.id] = nil
        }
        .alert(Text("Clear \(info.title)?", bundle: .module,
                    comment: "Settings ▸ Shortcuts: title of the confirmation before clearing Back to Standard; the argument is the shortcut’s name"),
               isPresented: $confirmingClear) {
            Button(role: .destructive) {
                services.shortcuts.set(shortcut.id, nil)
            } label: {
                Text("Clear Shortcut", bundle: .module,
                     comment: "Settings ▸ Shortcuts: confirms clearing the Back to Standard shortcut (title case)")
            }
            Button(role: .cancel) {} label: {
                Text("Cancel", bundle: .module, comment: "Settings: cancel button of a confirmation (title case)")
            }
        } message: {
            Text("Without this shortcut, use Turn Off Overbright in the menu or the panel. It does the same, a little more slowly.",
                 bundle: .module, comment: "Settings ▸ Shortcuts: why clearing Back to Standard asks first")
        }
    }

    /// The caps of `combo` as the live binding shows them (the center's layout), or in the display layout for a
    /// combination that is not registered (a conflict).
    private func keys(for combo: KeyCombo?) -> String? {
        guard let combo else { return nil }
        return services.shortcuts.displayString(shortcut.id) ?? KeyComboFormatter.keyCaps(combo)
    }

    /// The first problem with `combo`: a twin among Overbright's own shortcuts (which also makes the second one fail to
    /// register), a combination another app owns, then an enabled macOS shortcut.
    private func warning(for combo: KeyCombo?) -> String? {
        guard let combo else { return nil }
        let settings = services.settings
        if let other = ShortcutCatalog.all.first(where: { other in
            other.id != shortcut.id && Self.effectiveCombo(other, settings: settings) == combo
        }) {
            let name = names[other.id] ?? other.id.rawValue
            return String(localized: "Already used for \(name).", bundle: .module,
                          comment: "Settings ▸ Shortcuts: two Overbright shortcuts share keys; the argument is the other shortcut’s name")
        }
        if case .conflict = services.shortcuts.state(shortcut.id) {
            return String(localized: "Another app already uses this shortcut.", bundle: .module,
                          comment: "Settings ▸ Shortcuts: the shortcut could not be registered")
        }
        if let clash = SystemShortcuts.conflict(for: combo, in: system) {
            if let name = SystemShortcuts.name(of: clash.id) {
                return String(localized: "macOS uses this for \(name).", bundle: .module,
                              comment: "Settings ▸ Shortcuts: an Overbright shortcut collides with a macOS shortcut; the argument is its name")
            }
            return String(localized: "macOS also uses this shortcut.", bundle: .module,
                          comment: "Settings ▸ Shortcuts: an Overbright shortcut collides with an unnamed macOS shortcut")
        }
        return nil
    }

    /// The user's binding wins; an explicit nil means cleared; no entry means the catalog default.
    static func effectiveCombo(_ shortcut: GlobalShortcut, settings: SettingsStore) -> KeyCombo? {
        if let binding = settings[ShortcutSettings.bindings][shortcut.id] { return binding }
        return shortcut.defaultCombo
    }
}

#Preview("Shortcut row") {
    let services = OverbrightServices.preview()
    let shortcut = ShortcutCatalog.all[0]
    Form {
        ShortcutRow(info: SettingsRowInfo(.shortcuts, "shortcut.\(shortcut.id.rawValue)", title: "Turn Overbright on or off"),
                    shortcut: shortcut, services: services, names: [:], system: SystemShortcuts.knownDefaults)
    }
    .formStyle(.grouped)
    .frame(width: 600, height: 120)
}
