// OverbrightDesignTests/CopyLanguageTests.swift — one localization of Design's catalog by its code (ARCHITECTURE.md
// §8.8; the fit tests of every module read Design's words through it). It is opened from its `.lproj` folder by path, for
// every shipped language and also while many lookups run at once; an empty code, a path or a language the catalog does
// not ship gives nil, never another language and never English in its place (WP14 C-PANEL-33).
import Foundation
import Testing
@testable import OverbrightDesign

@Suite nonisolated struct CopyLanguageTests {
    @Test func everyShippedLanguageOpensItsOwnFolderUnderParallelLoad() async {
        let codes = CopyLanguage.available
        #expect(codes.count == 35 && codes.contains("en") && codes.contains("ru"))
        let opened = await withTaskGroup(of: (String, String?).self) { group in
            for round in 0..<8 {
                for code in codes {
                    group.addTask { ("\(code)#\(round)", CopyLanguage.named(code)?.bundle.bundleURL.lastPathComponent) }
                }
            }
            var results: [String: String?] = [:]
            for await (name, folder) in group { results[name] = folder }
            return results
        }
        #expect(opened.count == codes.count * 8)
        let wrong = opened.filter { name, folder in folder != "\(name.prefix { $0 != "#" }).lproj" }.keys.sorted()
        #expect(wrong == [])
    }

    /// `Bundle.path(forResource: "", ofType: "lproj")` answers with the first localization it lists (German), and a
    /// relative path reaches a folder outside the code's own.
    @Test func anEmptyCodeAPathOrAMissingLanguageGivesNil() throws {
        #expect(CopyLanguage.named("") == nil)
        #expect(CopyLanguage.named("../en") == nil && CopyLanguage.named("ru/../ru") == nil)
        #expect(CopyLanguage.named("tlh") == nil && CopyLanguage.named("Base") == nil)
        let russian = try #require(CopyLanguage.named("ru", timeZone: .gmt))
        #expect(russian.locale.identifier == "ru" && russian.bundle.bundleURL.lastPathComponent == "ru.lproj")
        let resources = try #require(CopyLanguage.app.bundle.resourceURL)
        #expect(CopyLanguage.localization("ru", in: resources.appending(path: "ru.lproj")) == nil)  // no ru.lproj in it
    }
}
