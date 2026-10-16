// OverbrightDesign/Copy/BannerModel.swift — what the panel's one banner shows. DESIGN.md §5.8, §12.3; ARCHITECTURE.md
// §6.3. Seam written by WP0a (ARCHITECTURE.md §10.0): the type and `make(_:)` are fixed; WP9 writes the copy and the
// precedence-specific actions. The same sentence is the first, disabled line of the status menu, and its primary action
// the second line in title case.
import Foundation
import OverbrightCore

/// The panel's banner for a reason that applies to every display (also the first line of the status menu).
public nonisolated struct BannerModel: Hashable, Sendable {
    /// The glyph.
    public var symbol: OverbrightSymbol
    /// The glyph colour and the 10 % card tint.
    public var color: SemanticColor
    /// The sentence ("Paused because Low Power Mode is on."), already localized.
    public var sentence: String
    /// The primary action's title (sentence case), if any.
    public var primaryTitle: String?
    /// The secondary action's title, if any.
    public var secondaryTitle: String?
    /// What the primary button does.
    public var primaryAction: FixAction?
    /// The primary action in the status menu (title case).
    public var primaryMenuTitle: String?

    /// A banner.
    public init(symbol: OverbrightSymbol, color: SemanticColor, sentence: String, primaryTitle: String?,
                secondaryTitle: String?) {
        self.symbol = symbol; self.color = color; self.sentence = sentence
        self.primaryTitle = primaryTitle; self.secondaryTitle = secondaryTitle
    }

    /// A banner whose primary button is `action` in `language`.
    public init(symbol: OverbrightSymbol, color: SemanticColor, sentence: String, action: FixAction?,
                in language: CopyLanguage) {
        self.init(symbol: symbol, color: color, sentence: sentence, primaryTitle: action?.title(in: language),
                  secondaryTitle: nil)
        primaryAction = action
        primaryMenuTitle = action?.menuTitle(in: language)
    }

    /// The banner of `banner` (DESIGN.md §12.3).
    public static func make(_ banner: Banner) -> BannerModel { make(banner, displayNames: [:], in: .app) }

    /// The banner of `banner`; `displayNames` names the display a stop happened on.
    public static func make(_ banner: Banner, displayNames: [DisplayKey: String], in language: CopyLanguage) -> BannerModel {
        let (b, l) = (language.bundle, language.locale)
        func model(_ symbol: OverbrightSymbol, _ color: SemanticColor, _ sentence: String, _ action: FixAction?) -> BannerModel {
            BannerModel(symbol: symbol, color: color, sentence: sentence, action: action, in: language)
        }
        func name(_ key: DisplayKey) -> String? { displayNames[key].map(\.overbrightIsolated) }
        switch banner {
        case let .userPaused(until):
            let time = CopyFormat.time(until, in: language)
            return model(.pauseCircleFill, .neutral,
                         String(localized: "Overbright is paused until \(time).", bundle: b, locale: l,
                                comment: "Panel: banner while the user paused Overbright; the argument is a time of day"), .resume)
        case let .conflict(app) where app.severity == .booster:
            let app = app.displayName.overbrightIsolated
            return model(.exclamationMarkTriangleFill, .warning,
                         String(localized: "Paused because \(app) also changes display brightness. Quit it, or use Compatibility mode, which works alongside it.",
                                bundle: b, locale: l, comment: "Panel: banner while another brightness app runs; the argument is its name"),
                         .useCompatibilityMode)
        case let .conflict(app):
            let app = app.displayName.overbrightIsolated
            return model(.exclamationMarkTriangleFill, .warning,
                         String(localized: "Paused because \(app) changes display colors. Night Shift gives warm light without a conflict.",
                                bundle: b, locale: l, comment: "Panel: banner while a color app runs; the argument is its name; “Night Shift” is macOS’s own name"),
                         .continueAnyway)
        case .foreignTableAtLaunch:
            return model(.exclamationMarkTriangleFill, .danger,
                         String(localized: "Another app changed the display colors and they couldn’t be reset. Change the color profile or preset in Displays settings and back, or log out.",
                                bundle: b, locale: l, comment: "Panel: banner when another app left changed display colors at launch"),
                         .openSystemSettings)
        case let .flickerStop(display):
            let sentence = name(display).map {
                String(localized: "Overbright stopped on \($0) to prevent flicker.", bundle: b, locale: l,
                       comment: "Panel: banner after the flicker guard stopped a display; the argument is the display’s name")
            } ?? String(localized: "Overbright stopped on a display to prevent flicker.", bundle: b, locale: l,
                        comment: "Panel: banner after the flicker guard stopped a display whose name is unknown")
            return model(.exclamationMarkTriangleFill, .danger, sentence, .tryAgain)
        case let .unattributedDrift(display):
            let sentence = name(display).map {
                String(localized: "Another app keeps changing the colors of \($0), so Overbright stopped there.", bundle: b, locale: l,
                       comment: "Panel: banner after repeated color changes by an unknown app; the argument is the display’s name")
            } ?? String(localized: "Another app keeps changing the colors of a display, so Overbright stopped there.", bundle: b,
                        locale: l, comment: "Panel: banner after repeated color changes on a display whose name is unknown")
            return model(.exclamationMarkTriangleFill, .danger, sentence, .tryAgain)
        case let .attributedDrift(app, display):
            let app = app.displayName.overbrightIsolated
            let sentence = name(display).map {
                String(localized: "\(app) changed the colors of \($0), so Overbright stopped there.", bundle: b, locale: l,
                       comment: "Panel: banner after an app changed a display’s colors; the arguments are the app’s and the display’s names")
            } ?? String(localized: "\(app) changed the colors of a display, so Overbright stopped there.", bundle: b, locale: l,
                        comment: "Panel: banner after an app changed the colors of a display whose name is unknown")
            return model(.exclamationMarkTriangleFill, .danger, sentence, .continueAnyway)
        case .focusOff:
            return model(.moonFill, .neutral,
                         String(localized: "Off because of the current Focus.", bundle: b, locale: l,
                                comment: "Panel: banner while a Focus turned extra brightness off; “Focus” is macOS’s own name"),
                         .openSystemSettings)
        case .thermalCritical:
            return model(.thermometerHigh, .warning,
                         String(localized: "Paused because your Mac is hot. Overbright continues when it cools down.", bundle: b,
                                locale: l, comment: "Panel: banner while the Mac is hot"), nil)
        case .lowPowerMode:
            return model(.boltFill, .neutral,
                         String(localized: "Paused because Low Power Mode is on.", bundle: b, locale: l,
                                comment: "Panel: banner in Low Power Mode; “Low Power Mode” is macOS’s own name"), .changePowerRules)
        case let .battery(_, threshold):
            let percent = CopyFormat.percent(threshold, in: language)
            return model(.battery25Percent, .neutral,
                         String(localized: "Paused because the battery is below \(percent).", bundle: b, locale: l,
                                comment: "Panel: banner on battery below the threshold; the argument is a percentage such as 20%"),
                         .changePowerRules)
        case .onBattery:
            return model(.battery25Percent, .neutral,
                         String(localized: "Paused while on battery.", bundle: b, locale: l,
                                comment: "Panel: banner on battery when extra brightness runs only on the adapter"), .changePowerRules)
        case let .outsideSchedule(window):
            let from = CopyFormat.time(minuteOfDay: window.startMinute, in: language)
            let to = CopyFormat.time(minuteOfDay: window.endMinute, in: language)
            return model(.clockFill, .neutral,
                         String(localized: "Extra brightness is allowed from \(from) to \(to).", bundle: b, locale: l,
                                comment: "Panel: banner outside the set hours; the arguments are times of day"), .changeHours)
        }
    }
}
