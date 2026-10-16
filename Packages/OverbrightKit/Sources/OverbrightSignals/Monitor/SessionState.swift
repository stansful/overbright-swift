// OverbrightSignals/Monitor/SessionState.swift — the session facts read at launch. ARCHITECTURE.md §3.3
// (`isSessionActive`, `isScreenLocked`), §7.1 ("Lock / unlock", "Fast user switching, console"), D27.
// Thread: any (a value type).

/// Whether our session is on the console and whether its screen is locked, at the moment of the read. After launch the
/// lock and session notifications keep `SystemSnapshot` current.
nonisolated struct SessionState: Hashable, Sendable {
    /// `kCGSessionOnConsoleKey` (false: another user's session has the screen; no table writes, D27).
    var isOnConsole: Bool
    /// `CGSSessionScreenIsLocked` (undocumented, read at launch only; absent means unlocked).
    var isScreenLocked: Bool
}
