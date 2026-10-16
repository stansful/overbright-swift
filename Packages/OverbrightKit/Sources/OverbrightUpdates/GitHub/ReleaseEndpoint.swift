// OverbrightUpdates/GitHub/ReleaseEndpoint.swift — which endpoint answers "what is the newest release?". Ported from
// Cranny's UpdateChecker+GitHub.swift (the owner's MIT code). D2.
import Foundation

/// The GitHub Releases endpoint a check asks.
nonisolated enum ReleaseEndpoint: String, Codable, Sendable {
    /// `/releases/latest`: the newest published, non-draft, non-pre-release release.
    case latest
    /// `/releases?per_page=20`: recent releases incl. pre-releases (Settings ▸ General ▸ Include pre-releases).
    case list

    init(includesPrereleases: Bool) { self = includesPrereleases ? .list : .latest }

    /// `perPage` applies to `.list` only (`per_page=1` tells "no stable release yet" from "no repository").
    func url(repository: String, perPage: Int = 20) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.github.com"
        components.path = "/repos/\(repository)/releases" + (self == .latest ? "/latest" : "")
        if self == .list { components.queryItems = [URLQueryItem(name: "per_page", value: String(perPage))] }
        return components.url
    }

    /// Decodes one release (`latest`) or a list (`list`).
    func decode(_ data: Data) throws -> [GitHubRelease] {
        switch self {
        case .latest: [try JSONDecoder().decode(GitHubRelease.self, from: data)]
        case .list: try JSONDecoder().decode([GitHubRelease].self, from: data)
        }
    }
}
