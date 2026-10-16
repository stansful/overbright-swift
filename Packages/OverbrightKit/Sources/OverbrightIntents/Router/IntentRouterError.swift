// OverbrightIntents/Router/IntentRouterError.swift — why an intent failed. DESIGN.md §12.8 ("Errors").
// ARCHITECTURE.md §7.7, §10.0 (the cases are the WP0a seam); the localized sentences are WP8's, in the Intents
// catalog (runtime strings resolve against this module's bundle; only extracted intent metadata needs the app's).
import Foundation

/// The failures of DESIGN.md §12.8. The Shortcuts app shows `localizedStringResource`; `errorDescription` is the same
/// sentence for everything else (logs, tests).
public nonisolated enum IntentRouterError: Error, Hashable, Sendable {
    /// "Overbright is still starting. Try again in a moment."
    case notReady
    /// "That display isn’t connected."
    case displayNotConnected
    /// "This display can’t show extra brightness."
    case cannotBoost
    /// "This display can’t be dimmed."
    case cannotDim
}

extension IntentRouterError: CustomLocalizedStringResourceConvertible {
    /// The sentence of DESIGN.md §12.8, resolved in the requester's language.
    public var localizedStringResource: LocalizedStringResource {
        let bundle = LocalizedStringResource.BundleDescription.atURL(Bundle.module.bundleURL)
        return switch self {
        case .notReady:
            LocalizedStringResource("Overbright is still starting. Try again in a moment.", bundle: bundle,
                                    comment: "Shortcuts app: error when an action runs before Overbright finished starting (5 s).")
        case .displayNotConnected:
            LocalizedStringResource("That display isn’t connected.", bundle: bundle,
                                    comment: "Shortcuts app: error when the chosen display is not connected.")
        case .cannotBoost:
            LocalizedStringResource("This display can’t show extra brightness.", bundle: bundle,
                                    comment: "Shortcuts app: error of Set Extra Brightness on a display without extra range.")
        case .cannotDim:
            LocalizedStringResource("This display can’t be dimmed.", bundle: bundle,
                                    comment: "Shortcuts app: error of Dim Displays on a display without a color table.")
        }
    }
}

extension IntentRouterError: LocalizedError {
    /// The same sentence, resolved now.
    public var errorDescription: String? { String(localized: localizedStringResource) }
}
