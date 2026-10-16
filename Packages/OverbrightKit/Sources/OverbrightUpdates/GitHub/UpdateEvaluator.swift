// OverbrightUpdates/GitHub/UpdateEvaluator.swift — the newest eligible release against the running version (pure).
// Ported from Cranny's UpdateChecker+GitHub.swift (the owner's MIT code); the states carry Core's `UpdateState`
// payloads (the check's date, the release page). D2.
import Foundation
import OverbrightCore

/// Compares releases with the running version.
nonisolated enum UpdateEvaluator {
    /// The newest eligible release compared with `currentVersion`. Tags that are not semantic versions and drafts are
    /// ignored; pre-releases count only when the user opted in. `checkedAt` stamps an "up to date" answer.
    static func evaluate(_ releases: [GitHubRelease], currentVersion: String, includesPrereleases: Bool,
                         repository: String, checkedAt: Date) -> UpdateState {
        guard let current = SemanticVersion(currentVersion) else { return .failed(message: UpdateFailure.badVersion.message) }
        var newest: (release: GitHubRelease, version: SemanticVersion)?
        for release in releases where !release.isDraft && (includesPrereleases || !release.isPrerelease) {
            guard let version = SemanticVersion(release.tagName), includesPrereleases || version.prerelease == nil else {
                continue
            }
            if newest.map({ $0.version < version }) ?? true { newest = (release, version) }
        }
        guard let (release, version) = newest, current < version else { return .upToDate(checkedAt: checkedAt) }
        guard let page = releasePage(release, repository: repository) else {
            return .failed(message: UpdateFailure.unreadable.message)
        }
        return .available(version: version.description, url: page)
    }

    /// The release page to open: GitHub's `html_url` when it really points at github.com over HTTPS, else the page
    /// built from the tag. Never a URL from elsewhere.
    static func releasePage(_ release: GitHubRelease, repository: String) -> URL? {
        if let url = release.htmlURL, url.scheme == "https", url.host() == "github.com" { return url }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "github.com"
        components.path = "/\(repository)/releases/tag/\(release.tagName)"
        return components.url
    }
}
