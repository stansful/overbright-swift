// OverbrightDesignTests/CopyLanguageTests.swift — one localization of Design's catalog by its code (ARCHITECTURE.md
// §8.8; the fit tests of every module read Design's words through it). It is opened from its own `.lproj` folder by
// path, for every shipped language and also while many lookups run at once (the lookup through
// `path(forResource:ofType:)` could come back nil under parallel load, so the fit tests of PanelUI and the HUD measured
// English in its place, WP14 C-PANEL-33). Only a real folder of that name counts: an empty code, a path or a language
// the catalog does not ship gives nil, never another language and never English in its place (the old lookup answered
// "" with the first folder it listed and followed "../ru" out of the resources).
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightDesign

@Suite nonisolated struct CopyLanguageTests {
    @Test func everyShippedLanguageOpensItsOwnFolderUnderParallelLoad() async throws {
        let codes = CopyLanguage.available
        #expect(codes.count == 35 && codes.contains("en") && codes.contains("ru"))
        let opened = await withTaskGroup(of: (String, String?, String?).self) { group in
            for round in 0..<8 {
                for code in codes {
                    group.addTask {
                        let language = CopyLanguage.named(code)
                        return ("\(code)#\(round)", language?.bundle.bundleURL.lastPathComponent,
                                language?.locale.identifier)
                    }
                }
            }
            var results: [String: (folder: String?, locale: String?)] = [:]
            for await (name, folder, locale) in group { results[name] = (folder, locale) }
            return results
        }
        #expect(opened.count == codes.count * 8)
        let wrong = opened.filter { name, found in
            let code = String(name.prefix { $0 != "#" })
            return found.folder != "\(code).lproj" || found.locale != code
        }.keys.sorted()
        #expect(wrong == [])
        let russian = try #require(CopyLanguage.named("ru"))
        #expect(LevelPreset.standard.localizedName(in: russian) != LevelPreset.standard.localizedName(in: .english()))
    }

    /// `Bundle.path(forResource: "", ofType: "lproj")` answers with the first localization it lists, and a relative
    /// path reaches a folder outside the code's own.
    @Test func anEmptyCodeAPathOrAMissingLanguageGivesNil() throws {
        #expect(CopyLanguage.named("") == nil)
        #expect(CopyLanguage.named("../en") == nil && CopyLanguage.named("../ru") == nil)
        #expect(CopyLanguage.named("ru/") == nil && CopyLanguage.named("ru/../ru") == nil)
        #expect(CopyLanguage.named("tlh") == nil && CopyLanguage.named("Base") == nil)
        let russian = try #require(CopyLanguage.named("ru", timeZone: .gmt))
        #expect(russian.locale.identifier == "ru" && russian.bundle.bundleURL.lastPathComponent == "ru.lproj")
        #expect(russian.timeZone == .gmt && CopyLanguage.named("ru")?.timeZone == .gmt)
        #expect(CopyLanguage.named("de", timeZone: .current)?.timeZone == .current)
        let resources = try #require(CopyLanguage.app.bundle.resourceURL)
        #expect(CopyLanguage.localization("ru", in: resources.appending(path: "ru.lproj")) == nil)  // no ru.lproj in it
    }
}
