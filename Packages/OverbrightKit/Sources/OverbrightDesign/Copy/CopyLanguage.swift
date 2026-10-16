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
    /// such localization.
    public static func named(_ code: String, timeZone: TimeZone = .gmt) -> CopyLanguage? {
        guard let path = Bundle.module.path(forResource: code, ofType: "lproj"), let bundle = Bundle(path: path) else {
            return nil
        }
        return CopyLanguage(bundle: bundle, locale: Locale(identifier: code), timeZone: timeZone)
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
