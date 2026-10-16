// OverbrightOnboarding/Chrome/OnboardingStrings.swift — this module's strings in one language, for tests and snapshots
// that check a localization without changing the process's language (ARCHITECTURE.md §8.8, §9.1 fit tests). Ported
// from Cranny's PreviewSupport.swift (the owner's MIT code).
import Foundation

extension Bundle {
    /// This module's strings in one language (`"ru"`), or nil when the catalogs have no such localization.
    static func onboardingStrings(_ language: String) -> Bundle? {
        Bundle.module.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:))
    }
}
