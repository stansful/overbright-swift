// App/Intents/DisplayQuery.swift — the displays the Shortcuts app offers and resolves. ARCHITECTURE.md §7.7; D8, D18.
// One-line forwards to `IntentRouter`, which waits for the engine like every intent.
import AppIntents
import OverbrightCore
import OverbrightIntents

/// "All Displays" first, then every online display that can boost or dim. A saved display that is not connected
/// still resolves, so running the shortcut says "That display isn’t connected." instead of failing silently.
struct DisplayQuery: EntityQuery {
    /// Resolved in the app process, like the intents.
    @available(macOS 27.0, *)
    static var allowedExecutionTargets: IntentExecutionTargets { .main }

    @Dependency private var router: IntentRouter

    @MainActor
    func entities(for identifiers: [DisplayEntity.ID]) async throws -> [DisplayEntity] {
        let keys = identifiers.filter { $0 != DisplayEntity.allDisplaysID }.map { DisplayKey(rawValue: $0) }
        let displays = keys.isEmpty ? [] : try await router.displayChoices(for: keys).map(DisplayEntity.init)
        return (identifiers.contains(DisplayEntity.allDisplaysID) ? [.allDisplays] : []) + displays
    }

    @MainActor
    func suggestedEntities() async throws -> [DisplayEntity] {
        [.allDisplays] + (try await router.displayChoices().map(DisplayEntity.init))
    }

    @MainActor
    func defaultResult() async -> DisplayEntity? { .allDisplays }
}
