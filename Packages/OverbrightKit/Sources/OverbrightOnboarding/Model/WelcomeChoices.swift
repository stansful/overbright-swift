// OverbrightOnboarding/Model/WelcomeChoices.swift — what Done and Skip apply (DESIGN.md §8: "Skip (and closing the
// window) applies every default, including the login item ('Open Overbright, keep it off', registered with
// SMAppService.mainApp). Done applies the choices of step 3."). Seeded by WP0b (ARCHITECTURE.md §10.2) with the launch
// behaviour and the update switch; WP12 owns it (§10.14) and adds the guards of step 3 (`SkipAppliesDefaultsTests`).
import Foundation
import Observation
import OverbrightCore

/// The choices made in the Welcome window.
@Observable final class WelcomeChoices {
    /// Step 3's login choice (default "Open Overbright, keep it off").
    var launchBehavior = GeneralSettings.launchBehavior.defaultValue
    /// Step 5's "Check for updates on GitHub" (off; shown only when the build has a repository).
    var checksForUpdates = UpdateSettings.automatic.defaultValue

    /// Done: the choices apply. The login item follows the launch behaviour through `AppControl`.
    func applyOnDone(to services: OverbrightServices) {
        services.app?.setLaunchBehavior(launchBehavior)
        if services.updates.isConfigured { services.settings[UpdateSettings.automatic] = checksForUpdates }
    }

    /// Skip, or the close button: every default applies, the login item included.
    func applyDefaults(to services: OverbrightServices) {
        services.app?.setLaunchBehavior(GeneralSettings.launchBehavior.defaultValue)
    }
}
