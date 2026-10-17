// OverbrightDesign/Copy/CopyLanguage.swift — where Design's words and number formats come from. DESIGN.md §12.5,
// §16; ARCHITECTURE.md §8.8. Builders use the app's language by default; tests, fit checks and the diagnostics report
// (`designString.ru`) ask for one localization of Design's catalog with its locale (Cranny's `CalendarLanguage`).
import Foundation

/// The bundle that holds the words and the locale and time zone that format the numbers and times in them.
public nonisolated struct CopyLanguage: Sendable {
    /// The catalog (Design's module bundle, or one of its `.lproj` folders).
    public let bundle: Bundle
    /// Number, percent, duration and time formats.
    public let locale: Locale
    /// Times of day ("Paused until 14:20").
    public let timeZone: TimeZone

    /// A language over `bundle`.
    public init(bundle: Bundle, locale: Locale, timeZone: TimeZone) {
        self.bundle = bundle; self.locale = locale; self.timeZone = timeZone
    }

    /// The app's language and the user's locale and time zone.
    public static var app: CopyLanguage {
        CopyLanguage(bundle: .module, locale: .autoupdatingCurrent, timeZone: .autoupdatingCurrent)
    }

    /// The catalog's `code` localization ("en", "ru") with that language's locale, nil when Design's bundle has no
    /// such localization (an empty code or a path included).
    public static func named(_ code: String, timeZone: TimeZone = .gmt) -> CopyLanguage? {
        guard let resources = Bundle.module.resourceURL, let bundle = localization(code, in: resources) else {
            return nil
        }
        return CopyLanguage(bundle: bundle, locale: Locale(identifier: code), timeZone: timeZone)
    }

    /// The `<code>.lproj` folder under `resources` as a bundle, or nil when there is no such folder. Found by its path,
    /// not through `Bundle.path(forResource:ofType:)`, which can return nil under parallel load although the folder is
    /// on disk, and answers an empty name with whichever localization it lists first (WP14 C-PANEL-33; Onboarding's
    /// tables, C-ONBOARD-3).
    static func localization(_ code: String, in resources: URL) -> Bundle? {
        guard !code.isEmpty, !code.contains("/") else { return nil }
        let folder = resources.appendingPathComponent("\(code).lproj", isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }
        return Bundle(url: folder)
    }

    /// The development language (English) with an English locale, so tests and fit checks read English whatever the
    /// system language. Where the catalog has no English table yet, a bundle without tables makes every lookup return
    /// its key (the English text) or its default value.
    public static func english(timeZone: TimeZone = .gmt) -> CopyLanguage {
        named("en", timeZone: timeZone)
            ?? CopyLanguage(bundle: Bundle(url: FileManager.default.temporaryDirectory) ?? .module,
                            locale: Locale(identifier: "en"), timeZone: timeZone)
    }

    /// The localizations Design's catalog ships.
    public static var available: [String] { Bundle.module.localizations.filter { $0 != "Base" }.sorted() }
}
