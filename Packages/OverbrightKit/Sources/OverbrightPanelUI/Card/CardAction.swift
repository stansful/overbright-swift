// OverbrightPanelUI/Card/CardAction.swift — the actions a card offers in its chip's popover, its inline buttons and
// as VoiceOver actions. DESIGN.md §5.4, §5.7, §12.2 (sentence case: panel buttons); the destinations are §12.2's
// "Action destinations" and §16's rule (System Settings is always "Open System Settings").
import Foundation
import OverbrightCore

/// One action of a display card.
public nonisolated enum CardAction: Hashable, Sendable {
    /// Clears a trip ("Try again").
    case tryAgain
    /// Opens Help at an anchor ("Learn more").
    case learnMore(String)
    /// Opens the self-test ("Run self-test…").
    case runSelfTest
    /// Switches the display to Compatibility mode ("Use Compatibility mode").
    case useCompatibilityMode
    /// Turns extra brightness on for the display ("Turn on"; an OLED asks first).
    case turnOnExtraBrightness
    /// The verdict's fix in System Settings ▸ Displays ("Open System Settings").
    case openDisplaySettings
    /// Settings ▸ Displays ▸ Add extra brightness only near full brightness ("Change setting…").
    case changeTaperSetting
    /// Settings ▸ Displays at the display's Limit row ("Choose Peak…").
    case choosePeak
    /// Settings ▸ Automations ▸ Apps and video ("Change rules…").
    case changeRules
    /// The paused-apps list ("Edit apps…").
    case editApps
    /// Continues next to an app that changes display colors ("Continue anyway").
    case continueAnyway(ConflictingApp)

    /// The button title (sentence case: a panel button, DESIGN.md §12).
    public var title: String {
        switch self {
        case .tryAgain:
            String(localized: "Try again", bundle: .module, comment: "Panel ▸ Display card: chip action that clears a stop")
        case .learnMore:
            String(localized: "Learn more", bundle: .module,
                   comment: "Panel: link that opens the Help window at the matching answer")
        case .runSelfTest:
            String(localized: "Run self-test…", bundle: .module,
                   comment: "Panel ▸ Display card: chip action that opens the self-test")
        case .useCompatibilityMode:
            String(localized: "Use Compatibility mode", bundle: .module,
                   comment: "Panel ▸ Display card: chip action that switches the display to Compatibility mode")
        case .turnOnExtraBrightness:
            String(localized: "Turn on", bundle: .module,
                   comment: "Panel ▸ Display card: button that turns extra brightness on for this display")
        case .openDisplaySettings:
            String(localized: "Open System Settings", bundle: .module,
                   comment: "Panel ▸ Display card: button that opens Displays settings in System Settings")
        case .changeTaperSetting:
            String(localized: "Change setting…", bundle: .module,
                   comment: "Panel ▸ Display card: chip action that opens the near-full-brightness option in Settings")
        case .choosePeak:
            String(localized: "Choose Peak…", bundle: .module,
                   comment: "Panel ▸ Display card: chip action that opens this display’s limit (Safe or Peak) in Settings")
        case .changeRules:
            String(localized: "Change rules…", bundle: .module,
                   comment: "Panel ▸ Display card: chip action that opens the apps and video pause rules in Settings")
        case .editApps:
            String(localized: "Edit apps…", bundle: .module,
                   comment: "Panel ▸ Display card: chip action that opens the list of apps that pause extra brightness")
        case .continueAnyway:
            String(localized: "Continue anyway", bundle: .module,
                   comment: "Panel ▸ Display card: chip action that continues next to an app that changed the colors")
        }
    }
}
