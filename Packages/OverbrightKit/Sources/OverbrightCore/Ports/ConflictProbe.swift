// OverbrightCore/Ports/ConflictProbe.swift — conflicting apps (implemented by OverbrightSignals). ARCHITECTURE.md §3.6, §7.2.
// Contract rule (§10.0): a requirement added after WP0a lands only together with a default implementation in a
// protocol extension in this file.

/// Finds running apps that also change display colours or brightness.
@MainActor public protocol ConflictProbe: AnyObject {
    /// Running catalogue matches.
    func runningConflicts() -> [ConflictingApp]
    /// On-demand libproc scan to name the app behind an unexplained drift (≈ 14 ms, off the main actor).
    func attributeDrift() async -> ConflictingApp?
}
