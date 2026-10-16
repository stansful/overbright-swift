// OverbrightUpdates/GitHub/ReleaseCache.swift — the last good answer of an endpoint, kept so a `304 Not Modified` can
// be evaluated (`~/Library/Caches/app.overbright.Overbright/updates/releases.json`, ARCHITECTURE.md §8.2). Ported from
// Cranny's UpdateChecker+GitHub.swift (the owner's MIT code).
import Foundation

/// The cached answer of one endpoint of one repository.
nonisolated struct ReleaseCache: Codable, Equatable, Sendable {
    var repository: String
    var endpoint: ReleaseEndpoint
    var etag: String
    var releases: [GitHubRelease]

    /// The ETag to send: only for the same repository and endpoint.
    func etag(repository: String, endpoint: ReleaseEndpoint) -> String? {
        repository == self.repository && endpoint == self.endpoint ? etag : nil
    }
}
