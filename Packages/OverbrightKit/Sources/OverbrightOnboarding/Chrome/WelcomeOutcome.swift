// OverbrightOnboarding/Chrome/WelcomeOutcome.swift — how the Welcome window ended (DESIGN.md §8). The shell's
// `WelcomeWindowController` closes the window on every outcome.

/// How the Welcome window ended.
public nonisolated enum WelcomeOutcome: Sendable, Equatable {
    /// Done (or Turn On Overbright) on the last step: the choices of step 3 apply.
    case done
    /// Skip setup (Esc, then confirmed) or the window's close button: every default applies, the login item included.
    case skipped
    /// Quit Overbright: nothing is recorded, so Welcome shows again at the next launch.
    case quit
}
