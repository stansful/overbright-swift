// OverbrightAppShell/Launch/SingleInstance.swift — one engine per user session. ARCHITECTURE.md §7.4, §10.2; D27.
// Seam written by WP0a (§10.0): `SingleInstance.handOverIfRunning(arguments:) -> Bool` is fixed; WP0b writes the body
// (another process with our bundle ID and a different PID → send it a reopen, then this one exits; test
// `secondInstanceHandsOverAndExits`). The shell skips the check for CLI modes and for launches wired to the simulated
// ports (`CompositionRoot.skipsSingleInstanceCheck`), never on the arguments alone.
import OverbrightCore

/// The single-instance check of D27.
enum SingleInstance {
    /// True when another Overbright runs in this session and has been asked to reopen: the caller then exits.
    /// WP0a seam: never (nothing in WP0a can write a table, so two instances cannot fight yet).
    static func handOverIfRunning(arguments: LaunchArguments = .current) -> Bool { false }
}
