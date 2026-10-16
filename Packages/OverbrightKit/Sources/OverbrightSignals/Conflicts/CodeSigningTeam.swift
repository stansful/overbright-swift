// OverbrightSignals/Conflicts/CodeSigningTeam.swift — the signing team of a bundle on disk. ARCHITECTURE.md §7.2 step 4
// (a team ID confirms a vendor-prefix match).
// `SecStaticCodeCreateWithPath` + `SecCodeCopySigningInformation` read the static signature: no permission, no network.
// `RunningAppsConflictProbe` asks only for bundles whose ID starts with a catalogued prefix that names teams, and caches
// the answer per bundle.
// Thread: any.
import Foundation
import Security

/// Reads code-signing team identifiers.
nonisolated enum CodeSigningTeam {
    /// The team identifier of the bundle at `url`; nil when unsigned, ad-hoc signed or unreadable.
    static func teamID(ofBundleAt url: URL) -> String? {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code else { return nil }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &information)
                == errSecSuccess,
              let dictionary = information as? [String: Any] else { return nil }
        return dictionary[kSecCodeInfoTeamIdentifier as String] as? String
    }
}
