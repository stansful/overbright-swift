// OverbrightPanelUI/Panel/BannerAction.swift — what the banner's button does (and the status menu's second line, in
// title case there). DESIGN.md §12.3 (one action per banner), §4.3, §16 (System Settings is "Open System Settings");
// ARCHITECTURE.md §6.3, §7.2 (an S1 booster, whether it runs or changed a display's colors, has no action: never
// Continue Anyway, so two tables never compound; the banner asks to quit it).
import OverbrightCore

/// The primary action of a banner.
public nonisolated enum BannerAction: Hashable, Sendable {
    /// Ends the user's pause.
    case resume
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

    /// The action of `banner`, nil when it has none (heat, a booster).
    public static func primary(for banner: Banner) -> BannerAction? {
        switch banner {
        case .userPaused: .resume
        case .conflict(let app): app.severity == .booster ? nil : .continueAnyway(app)
        case .foreignTableAtLaunch: .openDisplaySettings
        case .flickerStop(let display), .unattributedDrift(let display): .tryAgain(display)
        case .attributedDrift(let app, _): app.severity == .booster ? nil : .continueAnyway(app)
        case .focusOff: .openFocusSettings
        case .thermalCritical: nil
        case .lowPowerMode, .battery, .onBattery: .changePowerRules
        case .outsideSchedule: .changeHours
        }
    }

    /// Runs the action through `commands`.
    @MainActor
    public func perform(_ commands: PanelCommands) {
        let boost = commands.services.boost
        switch self {
        case .resume: boost.resume(source: commands.source)
        case .continueAnyway(let app): boost.continueAnyway(app)
        case .openDisplaySettings: commands.openSystemSettings(SettingsLinks.systemDisplays)
        case .openFocusSettings: commands.openSystemSettings(SettingsLinks.systemFocus)
        case .tryAgain(let display): boost.retry(display)
        case .changePowerRules: commands.openSettings(SettingsLinks.powerRules)
        case .changeHours: commands.openSettings(SettingsLinks.schedule)
        }
    }
}
