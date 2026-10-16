// App/Intents/OverbrightShortcuts.swift — the App Shortcuts (DESIGN.md §12.8). ARCHITECTURE.md §7.7; D18.
// In the app target on purpose: a provider declared in a Swift package is silently dropped [VERIFIED]. Phrases are in
// App/AppShortcuts.xcstrings, short titles in App/Localizable.xcstrings.
import AppIntents

/// "Turn Overbright on or off" and "Overbright back to Standard", ready without setup.
struct OverbrightShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ToggleOverbrightIntent(),
                    phrases: ["Turn \(.applicationName) on or off"],
                    shortTitle: "Turn On or Off",
                    systemImageName: "sun.max")
        AppShortcut(intent: ReturnToStandardIntent(),
                    phrases: ["\(.applicationName) back to Standard"],
                    shortTitle: "Back to Standard",
                    systemImageName: "sun.min")
    }
}
