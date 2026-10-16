// OverbrightOnboarding/Model/WelcomeDisplayRow.swift — one display as Welcome sees it (DESIGN.md §8 step 2, §12.1): the
// verdict the engine published for it (Policy's `EligibilityClassifier`, D8), its fix, whether it can show extra
// brightness at its limit and the "Use extra brightness" switch. Rows follow the display directory (built-in first),
// so they re-evaluate whenever the displays change, for example after HDR is turned on in System Settings. A display
// the engine has not classified yet reads "Checking…" and offers no switch. The derived numbers (the top of the boost
// half, the switch's class default, OLED) are PanelUI's `DisplayCardModel`, so the panel and Welcome never disagree.
import OverbrightCore
import OverbrightPanelUI
import OverbrightPolicy

/// One online display in Welcome.
struct WelcomeDisplayRow: Hashable, Identifiable {
    /// The fix button of a verdict (DESIGN.md §12.1).
    enum Fix: Hashable {
        /// "Open System Settings" (Displays settings: turn on HDR, switch the preset, leave a reference mode).
        case openSystemSettings
        /// "Choose Peak…": Safe adds nothing on this display (Settings ▸ Displays at its Limit row).
        case choosePeak
    }

    /// The display.
    let key: DisplayKey
    /// Its name (`NSScreen.localizedName`; never compared, D8).
    let name: String
    /// The built-in display (the laptop glyph).
    let isBuiltIn: Bool
    /// What it can do; `.checking` until the engine classified it.
    let verdict: DisplayVerdict
    /// The verdict's advisories (a second line under the sentence).
    let advisories: [Advisory]
    /// It can show extra brightness at its limit (Safe or Peak): the switch is offered.
    let canBoost: Bool
    /// The "Use extra brightness" switch: the stored preference, else the class default (D8).
    let boostEnabled: Bool
    /// OLED by class or override: turning extra brightness on asks first (DESIGN.md §12.4).
    let isOLED: Bool
    /// The light gain at the top of the boost half for the display's limit (1 when it cannot boost).
    let top: Double
    /// The fix button, if the verdict has one.
    let fix: Fix?

    /// The display's key.
    var id: DisplayKey { key }

    /// Extra brightness will show on this display when Overbright turns on.
    var boostsWhenOn: Bool { canBoost && boostEnabled }
}

extension WelcomeDisplayRow {
    /// Every online display, built-in first (the directory's order), with what the engine publishes about it.
    static func rows(in services: OverbrightServices) -> [WelcomeDisplayRow] {
        let statuses = services.boost.status.displays
        return services.displays.displays.map { facts in
            row(facts: facts, status: statuses.first { $0.key == facts.ref.key }, services: services)
        }
    }

    /// The row of one display: from its card model once the engine has a decision for it, else "Checking…".
    static func row(facts: DisplayFacts, status: DisplayStatus?, services: OverbrightServices) -> WelcomeDisplayRow {
        let preferences = services.settings[DisplaySettings.perDisplay][facts.ref.key] ?? DisplayPreferences()
        guard let status, let eligibility = status.decision?.eligibility else {
            let isOLED = EligibilityClassifier.isOLED(facts, override: preferences.oled)
            return WelcomeDisplayRow(key: facts.ref.key, name: facts.name, isBuiltIn: facts.isBuiltIn, verdict: .checking,
                                     advisories: [], canBoost: false,
                                     boostEnabled: preferences.boostEnabled ?? classDefault(facts, isOLED: isOLED),
                                     isOLED: isOLED, top: 1, fix: nil)
        }
        let card = DisplayCardModel(status: status, isMasterOn: false, services: services)
        return WelcomeDisplayRow(key: facts.ref.key, name: facts.name, isBuiltIn: facts.isBuiltIn,
                                 verdict: eligibility.verdict, advisories: eligibility.advisories,
                                 canBoost: card.canBoost, boostEnabled: card.boostEnabled, isOLED: card.isOLED,
                                 top: card.canBoost ? card.top : 1, fix: fix(for: card))
    }

    /// The fix of a card: System Settings for the verdicts it can fix there, Choose Peak… where Safe adds nothing.
    static func fix(for card: DisplayCardModel) -> Fix? {
        if let verdict = card.verdict, CardChip.verdictFix(verdict) == .openDisplaySettings { return .openSystemSettings }
        if case .unavailable(.safeLimitReached) = card.boostHalf { return .choosePeak }
        return nil
    }

    /// Built-in XDR and Apple XDR externals have extra brightness on by default; other HDR and OLED displays are
    /// opt-in (D8). Used only until the engine publishes the classifier's own default.
    static func classDefault(_ facts: DisplayFacts, isOLED: Bool) -> Bool {
        !isOLED && (facts.panelClass == .builtInXDR || facts.panelClass == .appleXDRExternal)
    }
}

extension [WelcomeDisplayRow] {
    /// Step 5 offers Turn On Overbright: some display shows extra brightness once it is on (DESIGN.md §8).
    var offersTurnOn: Bool { contains(where: \.boostsWhenOn) }
}
