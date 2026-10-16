// OverbrightCore/Model/App/UpdateState.swift — the update check's state (ported from Cranny). ARCHITECTURE.md §3.6, D2.
import Foundation

/// The state of the GitHub Releases update check (`UpdateChecking.state`).
public nonisolated enum UpdateState: Hashable, Sendable {
    /// No check ran yet.
    case idle
    /// A check runs.
    case checking
    /// The newest release is installed.
    case upToDate(checkedAt: Date)
    /// A newer release exists.
    case available(version: String, url: URL)
    /// The check failed (already localized).
    case failed(message: String)
}
