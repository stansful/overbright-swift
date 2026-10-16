// OverbrightSettingsUI/Panes/IconWarningRow.swift — the warning row at the top of General while the menu bar icon is not
// visible and the user did not hide it (DESIGN.md §4.4, §7.3; `AppControl.iconVisibility == .notVisible`): what may
// hide it, how to reach Overbright anyway (the on/off shortcut in the live key caps when one is registered, Finder or
// Spotlight) and, on macOS 26 and later, where to allow it in the menu bar, with Open System Settings.
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// "Overbright's icon isn't visible." with the explanation and Open System Settings.
struct IconWarningRow: View {
    /// The live key caps of the on/off shortcut, nil when it is cleared or not registered.
    let toggleKeys: String?
    @Environment(\.overbright) private var theme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.m) {
            Image(symbol: .exclamationMarkTriangleFill)
                .foregroundStyle(SemanticColor.warning.glyph(in: theme))
                .accessibilityHidden(true)
            RowLabel(title: GeneralRows.iconWarning.title,
                     footnote: Self.message(toggleKeys: toggleKeys, namesMenuBarSetting: Self.hasAllowInMenuBar))
            Spacer(minLength: Space.m)
            Button { SystemSettingsLink.open(SystemSettingsLink.menuBar) } label: {
                Text(verbatim: SystemSettingsLink.openSystemSettings)
            }
        }
        .accessibilityElement(children: .contain)
        .searchTarget(GeneralRows.iconWarning)
    }

    /// "Allow in the Menu Bar" exists on macOS 26 and later.
    static var hasAllowInMenuBar: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    /// The explanation: the shortcut clause only with `toggleKeys`, the Menu Bar sentence only where it applies.
    static func message(toggleKeys: String?, namesMenuBarSetting: Bool) -> String {
        let first: String
        if let toggleKeys {
            first = String(localized: "macOS may be hiding it, or the menu bar is too full to show it. You can still use \(toggleKeys), or open Overbright from Finder or Spotlight.",
                           bundle: .module,
                           comment: "Settings ▸ General: explanation of the icon warning; the placeholder is the live key caps of the on/off shortcut")
        } else {
            first = String(localized: "macOS may be hiding it, or the menu bar is too full to show it. You can still open Overbright from Finder or Spotlight.",
                           bundle: .module, comment: "Settings ▸ General: explanation of the icon warning when the on/off shortcut is cleared")
        }
        guard namesMenuBarSetting else { return first }
        let second = String(localized: "To show it, turn on Overbright under Allow in the Menu Bar in Menu Bar settings.", bundle: .module,
                            comment: "Settings ▸ General: last sentence of the icon warning on macOS 26 and later; “Allow in the Menu Bar” and “Menu Bar” are macOS’s own names")
        return String(localized: "\(first) \(second)", bundle: .module,
                      comment: "Settings: joins two sentences of one explanation; keep or drop the space as your language writes it")
    }
}

#Preview("Icon warning") {
    Form { IconWarningRow(toggleKeys: "⌃⌥⌘B") }
        .formStyle(.grouped)
        .frame(width: 640, height: 160)
        .overbrightThemeRoot()
}
