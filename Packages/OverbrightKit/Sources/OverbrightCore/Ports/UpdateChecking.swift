// OverbrightCore/Ports/UpdateChecking.swift — the update check (implemented by OverbrightUpdates). ARCHITECTURE.md §3.6, D2.
// Contract rule (§10.0): a requirement added after WP0a lands only together with a default implementation in a
// protocol extension in this file.
import Foundation
import Observation

/// The GitHub Releases update check.
@MainActor public protocol UpdateChecking: AnyObject, Observable {
    /// False while the Info.plist repository key is empty: no network at all (D2).
    var isConfigured: Bool { get }
    /// The repository's page ("https://github.com/owner/repo"), built from the same validated "owner/repo" the check
    /// asks (Info.plist, or a Debug build's `-OverbrightGitHubRepository` override); nil while not configured.
    /// Settings ▸ About links to it, so the link and the update check always agree.
    var repositoryURL: URL? { get }
    /// The last result.
    var state: UpdateState { get }
    /// Checks now (no-op while not configured).
    func checkNow()
}

public extension UpdateChecking {
    /// No repository page (added after WP0a through the contract lane, §10.0; `UpdateChecker` and the fakes that
    /// need a link implement it).
    var repositoryURL: URL? { nil }
}
