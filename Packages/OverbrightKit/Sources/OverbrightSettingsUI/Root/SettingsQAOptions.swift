// OverbrightSettingsUI/Root/SettingsQAOptions.swift — Debug-only visual QA options of the Settings window, read from
// launch arguments (the argument domain of `UserDefaults`), next to the shell's `--qa-settings <pane[#row]>`
// (ARCHITECTURE.md §8.5). Ported from Cranny's SettingsQAOptions (the owner's MIT code):
//
//   -OverbrightQASearch "<text>"     the sidebar search field starts with this text
//
// (`-OverbrightQAAppearance`, `-OverbrightQASnapshot` are the window controller's; `-OverbrightQAKeyboardLayout` is
// read where key caps are drawn.) No input is synthesized. Compiled out of Release builds (always nil there).
import Foundation

/// Debug QA options of the Settings window.
enum SettingsQAOptions {
    /// Initial text of the search field.
    static var search: String? {
        #if DEBUG
        UserDefaults.standard.string(forKey: "OverbrightQASearch")
        #else
        nil
        #endif
    }
}
