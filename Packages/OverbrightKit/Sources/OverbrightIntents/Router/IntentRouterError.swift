// OverbrightIntents/Router/IntentRouterError.swift — why an intent failed. DESIGN.md §12.8 ("Errors").
// Seam written by WP0a (ARCHITECTURE.md §10.0); WP8 adds the localized descriptions (Intents' catalog).

/// The failures of DESIGN.md §12.8.
public nonisolated enum IntentRouterError: Error, Hashable, Sendable {
    /// "Overbright is still starting. Try again in a moment."
    case notReady
    /// "That display isn't connected."
    case displayNotConnected
    /// "This display can't show extra brightness."
    case cannotBoost
    /// "This display can't be dimmed."
    case cannotDim
}
