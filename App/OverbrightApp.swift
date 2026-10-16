// App/OverbrightApp.swift — the app target's entry point. ARCHITECTURE.md §1.3, §7.7, D18.
// Everything else lives in OverbrightKit; besides this file the app target holds only the App Intents adapters of
// App/Intents (D18) and the control intent shared with the dormant Controls extension (Shared/).
import AppIntents
import SwiftUI
import OverbrightAppShell
import OverbrightIntents

/// The app. It creates the App Intents router before launch, so an intent that launches Overbright can resolve it
/// before `applicationDidFinishLaunching`; the composition root connects it once the services exist.
@main
struct OverbrightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let router = IntentRouter()
        AppDependencyManager.shared.add(dependency: router)
        AppDelegate.intentRouter = router
    }

    var body: some Scene {
        OverbrightScenes(appDelegate: appDelegate)
    }
}
