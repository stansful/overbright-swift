// OverbrightOnboarding/Chrome/WelcomeStep.swift — the five steps of the Welcome window, in order (DESIGN.md §8). Their
// raw values are the names `--qa-welcome <step>` and `WelcomeWindowController.show(step:)` take; never rename one.

/// A step of the Welcome window.
public nonisolated enum WelcomeStep: String, CaseIterable, Sendable {
    /// 1 · "Use your display’s extra range": the before/after card.
    case hello
    /// 2 · "Your displays": a verdict and a fix per display.
    case displays
    /// 3 · "How Overbright behaves": guards and launch behaviour.
    case defaults
    /// 4 · "Where to find Overbright": the menu bar, live key caps (or a link to Settings ▸ Shortcuts), Run Shortcut.
    case findIt
    /// 5 · "You’re set": the update toggle, Turn On Overbright and Done.
    case done

    /// The step a name stands for (case-insensitive); nil for an unknown name.
    public init?(name: String) {
        let folded = name.lowercased()
        guard let step = Self.allCases.first(where: { $0.rawValue.lowercased() == folded }) else { return nil }
        self = step
    }
}
