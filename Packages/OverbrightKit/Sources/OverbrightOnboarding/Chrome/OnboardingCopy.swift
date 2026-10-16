// OverbrightOnboarding/Chrome/OnboardingCopy.swift — strings used by more than one Welcome surface, so each key has
// exactly one translator comment (DESIGN.md §8, §12.4). Ported from Cranny's OnboardingCopy (the owner's MIT code).
import Foundation

/// Shared Welcome copy.
enum OnboardingCopy {
    /// The window's title (hidden in the title bar; read by VoiceOver and Mission Control).
    static var windowTitle: String {
        String(localized: "Welcome to Overbright", bundle: .module,
               comment: "Welcome: window title (VoiceOver and Mission Control read it; the title bar hides it)")
    }

    /// "Quit Overbright": the bottom-leading button of every step and the third button of the Skip alert.
    static var quit: String {
        String(localized: "Quit Overbright", bundle: .module,
               comment: "Welcome: quits the app (a button on every step and in the Skip setup alert, title case)")
    }

    /// "Done": the last step's button.
    static var done: String {
        String(localized: "Done", bundle: .module, comment: "Welcome ▸ Done: the button that ends setup (title case)")
    }

    /// "Skip": the Skip alert's confirming button.
    static var skip: String {
        String(localized: "Skip", bundle: .module, comment: "Welcome: the Skip setup alert’s button that skips setup (title case)")
    }
}
