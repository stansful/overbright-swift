// OverbrightOnboarding/Chrome/OnboardingStrings.swift — this module's strings in one language, for tests and snapshots
// that check a localization without changing the process's language (ARCHITECTURE.md §8.8, §9.1 fit tests). Ported
// from Cranny's PreviewSupport.swift (the owner's MIT code). The `.lproj` folder is found by its path inside the
// module bundle's resources, not through `Bundle.path(forResource:ofType:)`, which can return nil under parallel load
// although the folder is on disk (the flaky `WelcomePlanTests.progressLabelReadsStepNOfCount`, WP14 C-ONBOARD-3).
import Foundation

extension Bundle {
    /// This module's strings in one language (`"ru"`), or nil when the catalogs have no such localization.
    nonisolated static func onboardingStrings(_ language: String) -> Bundle? {
        guard let resources = Bundle.module.resourceURL else { return nil }
        return localizationFolder(language, in: resources)
    }

    /// The `<language>.lproj` folder under `resources` as a bundle, or nil when there is no such folder.
    nonisolated static func localizationFolder(_ language: String, in resources: URL) -> Bundle? {
        guard !language.isEmpty, !language.contains("/") else { return nil }
        let folder = resources.appendingPathComponent("\(language).lproj", isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }
        return Bundle(url: folder)
    }
}
