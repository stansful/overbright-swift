// OverbrightUpdates/GitHub/UpdateConfiguration.swift — which GitHub repository this build asks, and the running
// version. Ported from Cranny's UpdateChecker+GitHub.swift (the owner's MIT code). ARCHITECTURE.md §8.6 (Info.plist), D2.
import Foundation
import OverbrightCore

/// The repository this build checks and the version it runs.
nonisolated struct UpdateConfiguration: Equatable, Sendable {
    /// The Info.plist key that names the GitHub repository ("owner/repo"). Empty or missing disables the check; WP17
    /// sets it once the public repository exists, so until then no build makes any network request.
    static let repositoryInfoKey = "OverbrightGitHubRepository"

    /// "owner/repo", validated; nil = update checks are off in this build.
    var repository: String?
    /// `CFBundleShortVersionString` of the running app.
    var currentVersion: String

    init(repository: String?, currentVersion: String) {
        self.repository = repository.flatMap(Self.validRepository)
        self.currentVersion = currentVersion
    }

    /// The running app's configuration. Debug builds also accept `-OverbrightGitHubRepository owner/repo` on the command
    /// line (the arguments domain of `UserDefaults`), to test against a scratch repository.
    static func main(bundle: Bundle = .main) -> UpdateConfiguration {
        var repository = bundle.object(forInfoDictionaryKey: repositoryInfoKey) as? String
        #if DEBUG
        let arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        if let override = arguments[repositoryInfoKey] as? String { repository = override }
        #endif
        return UpdateConfiguration(repository: repository, currentVersion: AppInfo.current(bundle).version)
    }

    /// GitHub's owner and repository name rules, loosely: letters, digits, "-", "_" and "." in two parts.
    static func validRepository(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "/", omittingEmptySubsequences: false)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        guard parts.count == 2, parts.allSatisfy({ !$0.isEmpty && $0.unicodeScalars.allSatisfy(allowed.contains) }),
              !parts.contains(where: { $0 == "." || $0 == ".." }) else { return nil }
        return trimmed
    }
}
