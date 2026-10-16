// OverbrightSignals/Apps/GameCategory.swift — "is the frontmost app a game?" ARCHITECTURE.md §6.5, §7.3, D10.
// The optional games rule reads the app's `LSApplicationCategoryType` from its Info.plist (no permission): games set it
// so that macOS Game Mode engages. `public.app-category.games` and its `public.app-category.*-games` subcategories
// count; Apple's Games app is a launcher and never does (the launcher is not the game).
// Thread: any (the reader reads one plist from disk; the monitor caches answers per bundle).
import Foundation

/// Classifies apps by their declared category.
nonisolated enum GameCategory {
    /// The games category.
    static let games = "public.app-category.games"
    /// Launchers that declare the games category but are not games (compared case-insensitively).
    static let launcherBundleIDs: Set<String> = ["com.apple.games"]

    /// Whether `category` is games or a games subcategory, and the app is not a known launcher.
    static func isGame(category: String?, bundleID: String?) -> Bool {
        guard let category = category?.lowercased() else { return false }
        if let bundleID, launcherBundleIDs.contains(bundleID.lowercased()) { return false }
        return category == games || (category.hasPrefix("public.app-category.") && category.hasSuffix("-games"))
    }

    /// `LSApplicationCategoryType` of the bundle at `url`, nil when it has none or cannot be read.
    static func category(ofBundleAt url: URL) -> String? {
        let plist = url.appending(path: "Contents/Info.plist", directoryHint: .notDirectory)
        guard let data = try? Data(contentsOf: plist),
              let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return info["LSApplicationCategoryType"] as? String
    }
}
