// OverbrightUpdates/GitHub/UpdateFailure.swift — why a check failed, as a localized one-liner (Settings ▸ General and
// About show it after a check the user started; DESIGN.md §7.3). Ported from Cranny's UpdateChecker+GitHub.swift (the
// owner's MIT code). D2.
import Foundation

/// Why an update check failed.
nonisolated enum UpdateFailure: Error, Equatable, Sendable {
    /// `repositoryNotFound`: GitHub does not know `OverbrightGitHubRepository` (wrong, renamed or private), HTTP 404.
    case notConfigured, offline, rateLimited, server(Int), repositoryNotFound, unreadable, badVersion

    /// The failure an HTTP status other than 200 and 304 stands for. A 404 from `/releases/latest` is first checked
    /// against the list, since it also means "no stable release yet" (`UpdateChecker.latestNotFound`).
    static func http(_ status: Int) -> UpdateFailure {
        switch status {
        case 403, 429: .rateLimited
        case 404: .repositoryNotFound
        default: .server(status)
        }
    }

    /// The sentence Settings shows.
    var message: String {
        switch self {
        case .notConfigured:
            String(localized: "Update checks are not available in this build.", bundle: .module,
                   comment: "Settings ▸ General: update check failure, no GitHub repository configured")
        case .repositoryNotFound:
            String(localized: "GitHub couldn’t find Overbright’s releases. Try again later.", bundle: .module,
                   comment: "Settings ▸ General: update check failure, HTTP 404 (the configured repository does not exist)")
        case .offline:
            String(localized: "GitHub couldn’t be reached. Check your internet connection and try again.",
                   bundle: .module, comment: "Settings ▸ General: update check failure, network error")
        case .rateLimited:
            String(localized: "GitHub is limiting requests right now. Try again later.", bundle: .module,
                   comment: "Settings ▸ General: update check failure, HTTP 403/429")
        case .server(let status):
            String(localized: "GitHub answered with an error (\(status)). Try again later.", bundle: .module,
                   comment: "Settings ▸ General: update check failure, other HTTP status; the number is the status code")
        case .unreadable, .badVersion:
            String(localized: "The release information couldn’t be read.", bundle: .module,
                   comment: "Settings ▸ General: update check failure, unexpected response")
        }
    }
}
