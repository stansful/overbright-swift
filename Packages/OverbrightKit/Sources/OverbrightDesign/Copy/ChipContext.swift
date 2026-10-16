// OverbrightDesign/Copy/ChipContext.swift — the facts a chip's words need beyond its reason. DESIGN.md §12.2.
// `ChipModel.make(reason:phase:failedTries:)` (the fixed seam) uses an empty context and the sentence variants without
// numbers or names; the panel passes what it knows about the display.
import Foundation
import OverbrightCore

/// What a status chip may quote: the gain macOS allows now, the paused app's name, the display's Safe facts.
public nonisolated struct ChipContext: Sendable {
    /// The light gain macOS allows now ("macOS allows ×1.55 right now"), for `LimitReason.headroom`.
    public var allowedGain: Double?
    /// The name of the app a `pausedApp` rule matched (Finder's name); nil shows its bundle ID.
    public var appName: String?
    /// The display's Safe facts, for `LimitReason.safeLimit`.
    public var safeLimit: SafeLimitText?
    /// The display has the `compatibilityModeAdvised` advisory: "No extra range" then offers Compatibility mode.
    public var compatibilityAdvised: Bool
    /// The OLED idle pause of Settings ▸ Automations, in minutes.
    public var oledIdleMinutes: Int
    /// Where the words come from.
    public var language: CopyLanguage

    /// A context.
    public init(allowedGain: Double? = nil, appName: String? = nil, safeLimit: SafeLimitText? = nil,
                compatibilityAdvised: Bool = false, oledIdleMinutes: Int = 5, language: CopyLanguage = .app) {
        self.allowedGain = allowedGain; self.appName = appName; self.safeLimit = safeLimit
        self.compatibilityAdvised = compatibilityAdvised; self.oledIdleMinutes = oledIdleMinutes
        self.language = language
    }

    /// The context of a display from its engine status and facts; `appName` resolves a bundle ID to Finder's name.
    public static func of(_ status: DisplayStatus, facts: DisplayFacts?, appName: (String) -> String? = { _ in nil },
                          oledIdleMinutes: Int = 5, language: CopyLanguage = .app) -> ChipContext {
        let eligibility = status.decision?.eligibility
        let isOLED = eligibility?.advisories.contains(.oledCare) ?? (facts?.panelClass == .oledExternal)
        var safeTop: Double?
        if case let .supported(safeGain, _)? = eligibility?.verdict { safeTop = safeGain }
        let safe = facts.map {
            SafeLimitText(panelClass: $0.panelClass, isOLED: isOLED, safeTop: safeTop, sdrWhiteNits: status.sdrWhite?.nits)
        }
        var name: String?
        for case let .pausedApp(bundleID) in status.decision?.reasons ?? [] { name = appName(bundleID); break }
        return ChipContext(allowedGain: status.appliedGain, appName: name, safeLimit: safe,
                           compatibilityAdvised: eligibility?.advisories.contains(.compatibilityModeAdvised) ?? false,
                           oledIdleMinutes: oledIdleMinutes, language: language)
    }
}
