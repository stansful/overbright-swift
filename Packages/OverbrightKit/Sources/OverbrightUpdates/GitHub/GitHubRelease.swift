// OverbrightUpdates/GitHub/GitHubRelease.swift — the fields of a GitHub release the check reads (REST API "release"
// object; every other field is ignored). Ported from Cranny's UpdateChecker+GitHub.swift (the owner's MIT code). D2.
import Foundation

/// One release as GitHub's REST API returns it, reduced to what the check needs.
nonisolated struct GitHubRelease: Codable, Equatable, Sendable {
    /// "v0.2.0".
    var tagName: String
    /// The release page on github.com (checked before it is opened, `UpdateEvaluator.releasePage`).
    var htmlURL: URL?
    /// Drafts never count.
    var isDraft: Bool
    /// Counts only with Settings ▸ General ▸ Include pre-releases.
    var isPrerelease: Bool

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name", htmlURL = "html_url", isDraft = "draft", isPrerelease = "prerelease"
    }

    init(tagName: String, htmlURL: URL?, isDraft: Bool = false, isPrerelease: Bool = false) {
        self.tagName = tagName; self.htmlURL = htmlURL; self.isDraft = isDraft; self.isPrerelease = isPrerelease
    }
}
