// OverbrightAppShell/Launch/ApplicationsMover.swift — "Move to Applications?" for a launch from elsewhere.
// ARCHITECTURE.md §7.4, §10.2; DESIGN.md §4.4, §12.4. Seam written by WP0a (§10.0): `offerIfNeeded()` is fixed; WP0b
// writes the body (offer only outside /Applications or when translocated, remember Not Now per version in
// `OnboardingSettings.declinedMoveVersion`; `ApplicationsMoverTests`).
import OverbrightCore

/// The move-to-Applications offer, run before Welcome.
final class ApplicationsMover {
    private let settings: SettingsStore

    /// A mover that remembers "Not Now" in `settings`.
    init(settings: SettingsStore) { self.settings = settings }

    /// Asks the user to move Overbright to /Applications when it runs from elsewhere. WP0a seam: never asks.
    func offerIfNeeded() {}
}
