// OverbrightPanelUI/Panel/BannerAction.swift — what the banner's button does (and the status menu's second line, in
// title case there). DESIGN.md §12.3 (one action per banner), §4.3, §16 (System Settings is "Open System Settings");
// ARCHITECTURE.md §6.3, §7.2 (an S1 booster, whether it runs or changed a display's colors: Compatibility mode, which
// writes no table, instead of Continue Anyway, so two tables never compound).
import OverbrightCore

/// The primary action of a banner.
public nonisolated enum BannerAction: Hashable, Sendable {
    /// Ends the user's pause.
    case resume
    /// Next to a booster: Compatibility mode on every display that can boost, then continue.
    case useCompatibilityMode(ConflictingApp)
    /// Continues next to a color app.
    case continueAnyway(ConflictingApp)
    /// System Settings ▸ Displays.
    case openDisplaySettings
    /// System Settings ▸ Focus.
    case openFocusSettings
    /// Clears the stop on a display.
    case tryAgain(DisplayKey)
    /// Settings ▸ Automations ▸ Power.
    case changePowerRules
    /// Settings ▸ Automations ▸ Schedule.
    case changeHours

    /// The action of `banner`, nil when it has none (heat).
    public static func primary(for banner: Banner) -> BannerAction? {
        switch banner {
        case .userPaused: .resume
        case .conflict(let app): app.severity == .booster ? .useCompatibilityMode(app) : .continueAnyway(app)
        case .foreignTableAtLaunch: .openDisplaySettings
        case .flickerStop(let display), .unattributedDrift(let display): .tryAgain(display)
        case .attributedDrift(let app, _): app.severity == .booster ? .useCompatibilityMode(app) : .continueAnyway(app)
        case .focusOff: .openFocusSettings
        case .thermalCritical: nil
        case .lowPowerMode, .battery, .onBattery: .changePowerRules
        case .outsideSchedule: .changeHours
        }
    }

    /// Runs the action through `commands`. `status` names the displays that switch to Compatibility mode.
    @MainActor
    public func perform(_ commands: PanelCommands, status: BoostStatus) {
        let boost = commands.services.boost
        switch self {
        case .resume: boost.resume(source: commands.source)
        case .useCompatibilityMode(let app):
            let displays = status.displays.filter { $0.decision?.eligibility.verdict.allowsBoost ?? true }.map(\.key)
            commands.useCompatibilityMode(on: displays)
            boost.continueAnyway(app)
        case .continueAnyway(let app): boost.continueAnyway(app)
        case .openDisplaySettings: commands.openSystemSettings(SettingsLinks.systemDisplays)
        case .openFocusSettings: commands.openSystemSettings(SettingsLinks.systemFocus)
        case .tryAgain(let display): boost.retry(display)
        case .changePowerRules: commands.openSettings(SettingsLinks.powerRules)
        case .changeHours: commands.openSettings(SettingsLinks.schedule)
        }
    }
}
