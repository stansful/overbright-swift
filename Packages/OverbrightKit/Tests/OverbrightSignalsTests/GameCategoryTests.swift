// OverbrightSignalsTests/GameCategoryTests.swift — the games rule reads LSApplicationCategoryType. ARCHITECTURE.md §6.5,
// §7.3.
import Foundation
import Testing
@testable import OverbrightSignals

@Suite struct GameCategoryTests {
    @Test func gamesAndTheirSubcategoriesCount() {
        #expect(GameCategory.isGame(category: "public.app-category.games", bundleID: "com.example.game"))
        #expect(GameCategory.isGame(category: "public.app-category.action-games", bundleID: "com.example.game"))
        #expect(GameCategory.isGame(category: "public.app-category.Puzzle-Games", bundleID: nil))
    }

    @Test func otherCategoriesAndMissingOnesDoNot() {
        #expect(!GameCategory.isGame(category: "public.app-category.video", bundleID: "com.example.player"))
        #expect(!GameCategory.isGame(category: "public.app-category.entertainment", bundleID: "com.example.player"))
        #expect(!GameCategory.isGame(category: "games", bundleID: "com.example.game"))
        #expect(!GameCategory.isGame(category: nil, bundleID: "com.example.game"))
    }

    @Test func applesGamesLauncherIsNotAGame() {
        #expect(!GameCategory.isGame(category: "public.app-category.games", bundleID: "com.apple.games"))
        #expect(!GameCategory.isGame(category: "public.app-category.games", bundleID: "com.apple.Games"))
    }

    @Test func theCategoryIsReadFromTheBundlesInfoPlist() throws {
        let bundle = FileManager.default.temporaryDirectory
            .appending(path: "GameCategoryTests-\(UUID().uuidString).app", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: bundle) }
        let contents = bundle.appending(path: "Contents", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist = try PropertyListSerialization.data(fromPropertyList: ["LSApplicationCategoryType": "public.app-category.games",
                                                                         "CFBundleIdentifier": "com.example.game"],
                                                       format: .xml, options: 0)
        try plist.write(to: contents.appending(path: "Info.plist"))
        #expect(GameCategory.category(ofBundleAt: bundle) == "public.app-category.games")
        #expect(ProcessScanner.bundleIdentifier(ofBundleAt: bundle.path) == "com.example.game")
        #expect(GameCategory.category(ofBundleAt: bundle.appending(path: "Missing.app")) == nil)
    }
}
