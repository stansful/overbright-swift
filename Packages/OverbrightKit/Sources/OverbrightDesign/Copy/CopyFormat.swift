// OverbrightDesign/Copy/CopyFormat.swift — numbers, percentages, times and durations in copy. DESIGN.md §12.5, §16;
// ARCHITECTURE.md §8.8. Every number goes through `FormatStyle` / `Measurement` in the copy language's locale; the
// multiplier is preformatted ("×%@" needs no plural), a count of nits is a plural key.
import Foundation

/// The formats of DESIGN.md §12.5, in a `CopyLanguage`.
public nonisolated enum CopyFormat {
    /// "1.29" / "1,29": a light gain with two decimals (readouts, value tags, the HUD, chips).
    public static func number(_ gain: Double, in language: CopyLanguage = .app) -> String {
        gain.formatted(.number.precision(.fractionLength(2)).locale(language.locale))
    }

    /// "1.7" / "1,7": an approximate gain with one decimal (verdicts, "can reach ×2.6 at most", fixed caps).
    public static func roughNumber(_ gain: Double, in language: CopyLanguage = .app) -> String {
        gain.formatted(.number.precision(.fractionLength(1)).locale(language.locale))
    }

    /// "×1.29": a light gain as a multiplier.
    public static func multiplier(_ gain: Double, in language: CopyLanguage = .app) -> String {
        sign(number(gain, in: language), in: language)
    }

    /// "×2.6": an approximate multiplier with one decimal.
    public static func roughMultiplier(_ gain: Double, in language: CopyLanguage = .app) -> String {
        sign(roughNumber(gain, in: language), in: language)
    }

    /// "≈ ×1.29" while `isEstimate`, else "×1.29" (DESIGN.md §5.6: an uncalibrated multiplier is an estimate).
    public static func multiplier(_ gain: Double, isEstimate: Bool, in language: CopyLanguage = .app) -> String {
        let plain = multiplier(gain, in: language)
        return isEstimate ? approximately(plain, in: language) : plain
    }

    /// "1.29 times" (VoiceOver spells the sign out).
    public static func spokenMultiplier(_ gain: Double, in language: CopyLanguage = .app) -> String {
        times(number(gain, in: language), in: language)
    }

    /// "2.6 times": an approximate multiplier spoken, with one decimal.
    public static func spokenRoughMultiplier(_ gain: Double, in language: CopyLanguage = .app) -> String {
        times(roughNumber(gain, in: language), in: language)
    }

    /// "about 1.29 times" while `isEstimate`.
    public static func spokenMultiplier(_ gain: Double, isEstimate: Bool, in language: CopyLanguage = .app) -> String {
        let spoken = spokenMultiplier(gain, in: language)
        guard isEstimate else { return spoken }
        return String(localized: "about \(spoken)", bundle: language.bundle, locale: language.locale,
                      comment: "VoiceOver: an estimated value, as in “about 1.29 times”")
    }

    /// "≈ ×1.29": `text` marked as an estimate.
    public static func approximately(_ text: String, in language: CopyLanguage = .app) -> String {
        String(localized: "≈ \(text)", bundle: language.bundle, locale: language.locale,
               comment: "Panel: an estimated value, as in “≈ ×1.29”; the value is preformatted")
    }

    /// "≈ 775 nits": a luminance rounded to the nearest 5, always an estimate.
    public static func nits(_ nits: Double, in language: CopyLanguage = .app) -> String {
        let rounded = roundedNits(nits)
        return String(localized: "≈ \(rounded) nits", bundle: language.bundle, locale: language.locale,
                      comment: "Panel: an estimated luminance in nits, rounded to 5, as in “≈ 775 nits”")
    }

    /// "about 775 nits" (VoiceOver).
    public static func spokenNits(_ nits: Double, in language: CopyLanguage = .app) -> String {
        let rounded = roundedNits(nits)
        return String(localized: "about \(rounded) nits", bundle: language.bundle, locale: language.locale,
                      comment: "VoiceOver: an estimated luminance in nits, rounded to 5")
    }

    /// `nits` rounded to the nearest 5.
    public static func roundedNits(_ nits: Double) -> Int { Int((max(nits, 0) / 5).rounded()) * 5 }

    /// "25%" / "25 %": a percentage of Standard light or of the battery.
    public static func percent(_ percent: Int, in language: CopyLanguage = .app) -> String {
        (Double(percent) / 100).formatted(.percent.precision(.fractionLength(0)).locale(language.locale))
    }

    /// "14:20" / "2:20 PM": a time of day in the language's 12- or 24-hour clock.
    public static func time(_ date: Date, in language: CopyLanguage = .app) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened, locale: language.locale)
        style.timeZone = language.timeZone
        return date.formatted(style)
    }

    /// "14:20" for a minute of the day (the schedule's hours).
    public static func time(minuteOfDay minute: Int, in language: CopyLanguage = .app) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = language.timeZone
        let clamped = min(max(minute, 0), 1439)
        let midnight = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        let date = calendar.date(byAdding: .minute, value: clamped, to: midnight) ?? midnight
        return time(date, in: language)
    }

    /// "23 min" / "1 hr, 30 min": a duration in whole minutes.
    public static func duration(minutes: Int, in language: CopyLanguage = .app) -> String {
        Duration.seconds(max(minutes, 0) * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated).locale(language.locale))
    }

    /// "5 minutes" / "1 hour, 30 minutes": a duration in whole minutes, spelled out (sentences, VoiceOver, menus).
    public static func spokenDuration(minutes: Int, in language: CopyLanguage = .app) -> String {
        Duration.seconds(max(minutes, 0) * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .wide).locale(language.locale))
    }

    /// "10 sec" / "10 seconds": a countdown in whole seconds, abbreviated or spelled out.
    public static func seconds(_ seconds: Int, spelledOut: Bool, in language: CopyLanguage = .app) -> String {
        Duration.seconds(max(seconds, 0))
            .formatted(.units(allowed: [.seconds], width: spelledOut ? .wide : .abbreviated).locale(language.locale))
    }

    /// Two parts of a visible value: "Bright room · ×1.29".
    public static func parts(_ first: String, _ second: String, in language: CopyLanguage = .app) -> String {
        String(localized: "\(first) · \(second)", bundle: language.bundle, locale: language.locale,
               comment: "Panel: joins two parts of a value, as in “Bright room · ×1.29”")
    }

    /// Two parts joined by a comma: a spoken value ("Bright room, 1.29 times") or a compound name ("Tagged layer,
    /// black").
    public static func spokenParts(_ first: String, _ second: String, in language: CopyLanguage = .app) -> String {
        String(localized: "\(first), \(second)", bundle: language.bundle, locale: language.locale,
               comment: "Joins two parts with a comma: a spoken value (“Bright room, 1.29 times”) or a name (“Tagged layer, black”)")
    }

    /// Two sentences one after the other (languages that write no space between sentences drop it).
    public static func sentences(_ first: String, _ second: String, in language: CopyLanguage = .app) -> String {
        guard !first.isEmpty else { return second }
        guard !second.isEmpty else { return first }
        return String(localized: "\(first) \(second)", bundle: language.bundle, locale: language.locale,
                      comment: "Joins two sentences of one explanation; keep or drop the space as your language writes it")
    }

    private static func times(_ number: String, in language: CopyLanguage) -> String {
        String(localized: "\(number) times", bundle: language.bundle, locale: language.locale,
               comment: "VoiceOver: a light gain spoken, as in “1.29 times” for ×1.29; the number is preformatted")
    }

    private static func sign(_ number: String, in language: CopyLanguage) -> String {
        String(localized: "×\(number)", bundle: language.bundle, locale: language.locale,
               comment: "Panel: a light gain as a multiplier, as in “×1.29”; the number is preformatted")
    }
}
