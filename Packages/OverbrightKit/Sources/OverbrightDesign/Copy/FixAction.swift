// OverbrightDesign/Copy/FixAction.swift — the actions chips, banners and verdicts offer, with their titles.
// DESIGN.md §12.1–§12.3, §16 ("Destinations are unambiguous": Open System Settings goes to System Settings; a button
// into Overbright names the action). Panel buttons are sentence case; the status menu repeats a banner's primary
// action in title case. The surface that shows an action decides what it does (PanelUI, the shell).
import Foundation

/// An action that fixes or explains a limit.
public nonisolated enum FixAction: String, CaseIterable, Hashable, Sendable {
    /// Ends a pause the user set.
    case resume
    /// Clears a stop (no extra range, flicker, drift) and tries again.
    case tryAgain
    /// Opens the Help window at the matching answer.
    case learnMore
    /// Opens the self-test sheet.
    case runSelfTest
    /// Switches the display to Compatibility mode.
    case useCompatibilityMode
    /// Turns extra brightness on for the display (an OLED shows its notice first).
    case turnOn
    /// Opens Displays ▸ Add extra brightness only near full brightness.
    case changeSetting
    /// Opens Displays at the display's Limit row.
    case choosePeak
    /// Opens Automations ▸ Apps and video.
    case changeRules
    /// Opens the paused-apps list.
    case editApps
    /// Continues next to another color app.
    case continueAnyway
    /// Opens System Settings (the sentence names the pane).
    case openSystemSettings
    /// Opens Automations ▸ Power.
    case changePowerRules
    /// Opens Automations ▸ Schedule.
    case changeHours

    /// The button title in the panel (sentence case).
    public func title(in language: CopyLanguage = .app) -> String {
        let (b, l) = (language.bundle, language.locale)
        return switch self {
        case .resume: String(localized: "Resume", bundle: b, locale: l,
                             comment: "Panel: banner button that ends a pause the user set (also the menu item)")
        case .tryAgain: String(localized: "Try again", bundle: b, locale: l,
                               comment: "Panel: chip or banner button that tries a stopped display again (sentence case)")
        case .learnMore: String(localized: "Learn more", bundle: b, locale: l,
                                comment: "Panel: button that opens the Help window at the matching answer")
        case .runSelfTest: String(localized: "Run self-test…", bundle: b, locale: l,
                                  comment: "Panel: chip popover button that opens the self-test sheet (sentence case)")
        case .useCompatibilityMode: String(localized: "Use Compatibility mode", bundle: b, locale: l,
                                           comment: "Panel: chip or banner button that switches the display to Compatibility mode (sentence case)")
        case .turnOn: String(localized: "Turn on", bundle: b, locale: l,
                             comment: "Panel: chip button that turns extra brightness on for this display (sentence case)")
        case .changeSetting: String(localized: "Change setting…", bundle: b, locale: l,
                                    comment: "Panel: chip button that opens the setting Add extra brightness only near full brightness")
        case .choosePeak: String(localized: "Choose Peak…", bundle: b, locale: l,
                                 comment: "Panel: chip and verdict button that opens the display’s Limit setting to choose Peak")
        case .changeRules: String(localized: "Change rules…", bundle: b, locale: l,
                                  comment: "Panel: chip button that opens the full-screen and app pause rules")
        case .editApps: String(localized: "Edit apps…", bundle: b, locale: l,
                               comment: "Panel: chip button that opens the list of apps that pause extra brightness")
        case .continueAnyway: String(localized: "Continue anyway", bundle: b, locale: l,
                                     comment: "Panel: chip or banner button that continues next to another color app (sentence case)")
        case .openSystemSettings: String(localized: "Open System Settings", bundle: b, locale: l,
                                         comment: "Button that opens System Settings; the sentence beside it names the pane")
        case .changePowerRules: String(localized: "Change power rules…", bundle: b, locale: l,
                                       comment: "Panel: banner button that opens the battery and Low Power Mode rules (sentence case)")
        case .changeHours: String(localized: "Change hours…", bundle: b, locale: l,
                                  comment: "Panel: banner button that opens the hours extra brightness is allowed (sentence case)")
        }
    }

    /// The title in the status menu (title case, AppKit chrome).
    public func menuTitle(in language: CopyLanguage = .app) -> String {
        let (b, l) = (language.bundle, language.locale)
        return switch self {
        case .resume, .openSystemSettings, .choosePeak: title(in: language)
        case .tryAgain: String(localized: "Try Again", bundle: b, locale: l, comment: "Menu: banner action (title case)")
        case .learnMore: String(localized: "Learn More", bundle: b, locale: l, comment: "Menu: opens the Help window (title case)")
        case .runSelfTest: String(localized: "Run Self-Test…", bundle: b, locale: l,
                                  comment: "Menu and Settings: opens the self-test sheet (title case)")
        case .useCompatibilityMode: String(localized: "Use Compatibility Mode", bundle: b, locale: l,
                                           comment: "Menu: banner action (title case)")
        case .turnOn: String(localized: "Turn On", bundle: b, locale: l,
                             comment: "Menu: turns extra brightness on for a display (title case)")
        case .changeSetting: String(localized: "Change Setting…", bundle: b, locale: l, comment: "Menu: chip action (title case)")
        case .changeRules: String(localized: "Change Rules…", bundle: b, locale: l, comment: "Menu: chip action (title case)")
        case .editApps: String(localized: "Edit Apps…", bundle: b, locale: l,
                               comment: "Menu: opens the list of apps that pause extra brightness (title case)")
        case .continueAnyway: String(localized: "Continue Anyway", bundle: b, locale: l, comment: "Menu: banner action (title case)")
        case .changePowerRules: String(localized: "Change Power Rules…", bundle: b, locale: l,
                                       comment: "Menu: banner action (title case)")
        case .changeHours: String(localized: "Change Hours…", bundle: b, locale: l, comment: "Menu: banner action (title case)")
        }
    }
}
