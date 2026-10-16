// OverbrightPanelUITests/Support/ShippedLanguages.swift — the languages of WP15's all-language fit tests (ARCHITECTURE.md
// §8.8, §10.17): every localization Design's catalog ships, checked against scripts/l10n/languages.json, with Design's
// words (`CopyLanguage`) and this module's own table in one of them. Nothing changes the test process's language: each
// language is read from its `.lproj` folder.
import Foundation
import OverbrightDesign
@testable import OverbrightPanelUI

/// One shipped language.
nonisolated enum ShippedLanguages {
    /// Every language Overbright ships ("ar" … "zh-Hant", English included), as its catalogs name it.
    static let codes: [String] = CopyLanguage.available

    /// Design's words and number formats in `code`.
    static func design(_ code: String) -> CopyLanguage {
        CopyLanguage.named(code) ?? .english()
    }

    /// PanelUI's own table in `code`.
    static func panel(_ code: String) -> Bundle? {
        Bundle.module.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:))
    }

    /// The codes of `scripts/l10n/languages.json` (the list the catalogs, `Info.plist` and the release check share).
    static func listed() throws -> [String] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appending(path: "scripts/l10n/languages.json"))
        let entries = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        return entries.compactMap { $0["code"] as? String }.sorted()
    }
}

/// PanelUI's words in one language: `FooterText`'s and `PanelText`'s keys read from that language's table, with its
/// number and duration formats (the panel reads the same keys in the app's language).
nonisolated struct PanelWords {
    let bundle: Bundle
    let locale: Locale

    init(_ code: String) {
        bundle = ShippedLanguages.panel(code) ?? .module
        locale = Locale(identifier: code)
    }

    func below(_ percent: String) -> String { String(localized: "Below \(percent)", bundle: bundle, locale: locale) }
    var autoPause: String { String(localized: "Auto-pause", bundle: bundle, locale: locale) }
    var autoPauseOff: String { String(localized: "Auto-pause · Off", bundle: bundle, locale: locale) }
    var noTimer: String { String(localized: "No timer", bundle: bundle, locale: locale) }
    func offIn(_ duration: String) -> String { String(localized: "Off in \(duration)", bundle: bundle, locale: locale) }
    var off: String { String(localized: "Off", bundle: bundle, locale: locale) }
    var adapterOnly: String { String(localized: "Adapter only", bundle: bundle, locale: locale) }
    var anyCharge: String { String(localized: "Any charge", bundle: bundle, locale: locale) }

    /// "20 %" as `FooterText.percent` formats it, in this language's locale.
    func percent(_ value: Int) -> String { (Double(value) / 100).formatted(.percent.locale(locale)) }

    /// "1 h 30 min" as `FooterText.duration` formats it, in this language's locale.
    func duration(minutes: Int) -> String {
        Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated).locale(locale))
    }

    /// The readout caption of a display in Compatibility mode.
    var compatibilityMode: String { String(localized: "Compatibility mode", bundle: bundle, locale: locale) }
}
