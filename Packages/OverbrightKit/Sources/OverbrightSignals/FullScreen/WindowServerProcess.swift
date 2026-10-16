// OverbrightSignals/FullScreen/WindowServerProcess.swift — which process is the WindowServer. ARCHITECTURE.md §7.3 (the
// menu bar is matched by the WindowServer's PID, not by name), §10.8.
// The menu-bar windows belong to the WindowServer, recognised by its executable path (SIP-protected under /System),
// never by a process name (names are localized, and any process may call itself anything). In a full-screen Space every
// menu-bar window is off screen, so the on-screen window list cannot name it: `locate()` then scans every process once
// (≈ 5 ms, off the main actor), and `FullScreenTracker` keeps the PID for the rest of the session (the WindowServer
// outlives every app of the login session; when it restarts, the session and Overbright end with it).
// Thread: any; callers run it off the main actor.
import Foundation

/// Finds the WindowServer by its executable.
nonisolated enum WindowServerProcess {
    /// Whether an executable path is the WindowServer's (".../SkyLight.framework/Resources/WindowServer", under
    /// /System).
    static func isWindowServerPath(_ path: String) -> Bool {
        path.hasPrefix("/System/") && (path as NSString).lastPathComponent == "WindowServer"
    }

    /// Whether `pid` runs the WindowServer executable.
    static func isWindowServer(_ pid: Int32) -> Bool {
        LibProc.executablePath(of: pid).map(isWindowServerPath) ?? false
    }

    /// The WindowServer's PID from a scan of every process; nil when libproc cannot tell.
    static func locate() -> Int32? {
        locate(among: LibProc.allProcessIDs(), path: LibProc.executablePath)
    }

    /// The first of `pids` whose executable `path` is the WindowServer's.
    static func locate(among pids: [Int32], path: (Int32) -> String?) -> Int32? {
        pids.first { pid in path(pid).map(isWindowServerPath) ?? false }
    }
}
