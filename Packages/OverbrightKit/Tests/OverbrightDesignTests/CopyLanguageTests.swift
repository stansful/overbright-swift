// OverbrightDesignTests/CopyLanguageTests.swift — `CopyLanguage.named` opens one language of Design's catalog from its
// own `.lproj` folder (ARCHITECTURE.md §8.8): every shipped language resolves, also while many lookups run at once (the
// lookup through `path(forResource:ofType:)` could come back nil under parallel load, so the fit tests of PanelUI and
// the HUD measured English in its place, WP14 C-PANEL-33), and only a real folder of that name counts: a language the
// catalog lacks, an empty name or a path gives nil (the old lookup answered "" with the first folder, English, and
// followed "../ru" out of the resources).
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightDesign

@Suite struct CopyLanguageTests {
    @Test func everyLanguageResolvesFromItsOwnFolderUnderParallelLoad() async throws {
        let codes = CopyLanguage.available
        #expect(codes.count == 35)
        let resolved = await withTaskGroup(of: (String, Bool).self) { group in
            for round in 0..<8 {
                for code in codes {
                    group.addTask {
                        let language = CopyLanguage.named(code)
                        let found = language?.bundle.bundleURL.lastPathComponent == "\(code).lproj"
                            && language?.locale.identifier == code
                        return ("\(code)#\(round)", found)
                    }
                }
            }
            var results: [String: Bool] = [:]
            for await (name, found) in group { results[name] = found }
            return results
        }
        #expect(resolved.count == codes.count * 8)
        #expect(resolved.filter { !$0.value }.keys.sorted() == [])
        let russian = try #require(CopyLanguage.named("ru"))
        #expect(LevelPreset.standard.localizedName(in: russian) != LevelPreset.standard.localizedName(in: .english()))
    }

    @Test func onlyAFolderOfThatNameCounts() {
        #expect(CopyLanguage.named("tlh") == nil)                            // not a shipped language
        #expect(CopyLanguage.named("") == nil)                               // was the first folder (English)
        #expect(CopyLanguage.named("../ru") == nil && CopyLanguage.named("ru/") == nil)
        #expect(CopyLanguage.named("ru")?.timeZone == .gmt)
        #expect(CopyLanguage.named("de", timeZone: .current)?.timeZone == .current)
    }
}
