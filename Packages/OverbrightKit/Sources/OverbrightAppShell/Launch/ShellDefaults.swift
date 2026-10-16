// OverbrightAppShell/Launch/ShellDefaults.swift — the one `UserDefaults` the app keeps its own state in, chosen once at
// launch (AppDelegate) and handed to every writer: the settings store (through the composition root) and the Settings
// window's last pane and frame. Production uses the standard domain (`app.overbright.Overbright`). A Debug QA run
// started with `--qa-defaults-suite <name>` uses that suite instead (QAHooks+Defaults.swift), so hooks that change
// settings never touch the user's preferences. Ported from Cranny's ShellDefaults.swift (the owner's MIT code).
// ARCHITECTURE.md §7.4 (launch order), §8.2, §8.5. Seeded by WP0a (the launch order needs it); WP0b owns `Launch/`.
import Foundation
import OverbrightCore

/// Where the app keeps the state it stores in `UserDefaults`.
struct ShellDefaults {
    /// The defaults every writer in the app uses.
    let defaults: UserDefaults
    /// The suite of a QA run, nil for the standard domain.
    let qaSuite: String?

    /// The standard domain (production).
    static var standard: ShellDefaults { ShellDefaults(defaults: .standard, qaSuite: nil) }

    /// AppKit's window-frame autosave always writes the standard domain, so a QA run keeps frames for the run only.
    var autosavesWindowFrames: Bool { qaSuite == nil }

    /// The app's choice for this launch: the standard domain, or (Debug builds) the suite named by
    /// `--qa-defaults-suite`.
    static func forLaunch(_ arguments: LaunchArguments = .current) -> ShellDefaults {
        #if DEBUG
        if let qa = QAHooks.defaults(arguments) { return qa }
        #endif
        return .standard
    }
}
