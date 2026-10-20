// OverbrightOnboarding/Model/WelcomeDisplayRow.swift — one display as Welcome sees it (DESIGN.md §8 step 2, §12.1): the
// verdict the engine published for it (Policy's `EligibilityClassifier`, D8) in Design's words for the display's own
// limit (`VerdictText`, the only producer of verdict copy, so the sentence and the fix never contradict the limit), the
// fix that comes with those words, whether it can show extra brightness at its limit and the "Use extra brightness"
// switch (step 2's choice while one is pending, else the stored preference or the class default). Rows follow the
// display directory (built-in first), so they re-evaluate whenever the displays change, for example after HDR is
// turned on in System Settings. A display the engine has not classified yet reads "Checking…" and offers no switch.
// The derived numbers (the limit, the top of the boost half, the switch's class default, OLED) are PanelUI's
// `DisplayCardModel`, so the panel and Welcome never disagree.
import OverbrightCore
import OverbrightDesign
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

        /// The Welcome fix of a verdict's `FixAction`; nil for actions a verdict never offers.
        init?(_ action: FixAction?) {
            switch action {
            case .openSystemSettings?: self = .openSystemSettings
            case .choosePeak?: self = .choosePeak
            default: return nil
            }
        }
    }

    /// The display.
    let key: DisplayKey
    /// Its name (`NSScreen.localizedName`; never compared, D8).
    let name: String
    /// The built-in display (the laptop glyph).
    let isBuiltIn: Bool
    /// What it can do; `.checking` until the engine classified it.
    let verdict: DisplayVerdict
    /// The advisories Welcome shows under the sentence (`showsInWelcome`).
    let advisories: [Advisory]
    /// The display's limit: the supported sentence quotes it (DESIGN.md §12.1).
    let capMode: CapMode
    /// The verdict's badge, sentence, advisory lines and fix, for `capMode`.
    let text: VerdictText
    /// It can show extra brightness at its limit (Safe or Peak): the switch is offered.
    let canBoost: Bool
    /// The switch as stored: the preference, else the class default (D8).
    let storedBoostEnabled: Bool
    /// The switch on screen: step 2's pending choice, else `storedBoostEnabled`.
    let boostEnabled: Bool
    /// OLED by class or override: turning extra brightness on asks first (DESIGN.md §12.4).
    let isOLED: Bool
    /// The light gain at the top of the boost half for the display's limit (1 when it cannot boost).
    let top: Double
    /// The fix button, the one the verdict's words come with (`VerdictText.fix`).
    let fix: Fix?

    /// The display's key.
    var id: DisplayKey { key }

    /// Extra brightness will show on this display when Overbright turns on.
    var boostsWhenOn: Bool { canBoost && boostEnabled }

    /// The row with every word of its verdict passed through `transform` (the fit tests' pseudo-long locale); the
    /// display's name is data and stays as it is.
    func map(_ transform: (String) -> String) -> WelcomeDisplayRow {
        let words = VerdictText(badge: transform(text.badge), sentence: transform(text.sentence),
                                advisories: text.advisories.map(transform), fix: text.fix,
                                fixTitle: text.fixTitle.map(transform))
        return WelcomeDisplayRow(key: key, name: name, isBuiltIn: isBuiltIn, verdict: verdict, advisories: advisories,
                                 capMode: capMode, text: words, canBoost: canBoost,
                                 storedBoostEnabled: storedBoostEnabled, boostEnabled: boostEnabled, isOLED: isOLED,
                                 top: top, fix: fix)
    }
}

extension WelcomeDisplayRow {
    /// Every online display, built-in first (the directory's order), with what the engine publishes about it and
    /// step 2's pending switch choices, in `language`.
    static func rows(in services: OverbrightServices, choices: WelcomeChoices? = nil,
                     language: CopyLanguage = .app) -> [WelcomeDisplayRow] {
        let statuses = services.boost.status.displays
        return services.displays.displays.map { facts in
            row(facts: facts, status: statuses.first { $0.key == facts.ref.key }, services: services,
                choice: choices?.extraBrightness[facts.ref.key], language: language)
        }
    }

    /// The row of one display: from its card model once the engine has a decision for it, else "Checking…".
    /// `choice` is step 2's pending switch choice for it.
    static func row(facts: DisplayFacts, status: DisplayStatus?, services: OverbrightServices, choice: Bool? = nil,
                    language: CopyLanguage = .app) -> WelcomeDisplayRow {
        let settings = services.settings
        let preferences = settings[DisplaySettings.perDisplay][facts.ref.key] ?? DisplayPreferences()
        let idleMinutes = settings[AutomationSettings.oledIdleMinutes]
        guard let status, let eligibility = status.decision?.eligibility else {
            let isOLED = EligibilityClassifier.isOLED(facts, override: preferences.oled)
            let stored = preferences.boostEnabled ?? classDefault(facts, isOLED: isOLED)
            let text = VerdictText.make(.checking, advisories: [], lastGrant: nil, capMode: preferences.capMode,
                                        oledIdleMinutes: idleMinutes, in: language)
            return WelcomeDisplayRow(key: facts.ref.key, name: facts.name, isBuiltIn: facts.isBuiltIn, verdict: .checking,
                                     advisories: [], capMode: preferences.capMode, text: text, canBoost: false,
                                     storedBoostEnabled: stored, boostEnabled: choice ?? stored, isOLED: isOLED, top: 1,
                                     fix: nil)
        }
        let card = DisplayCardModel(status: status, isMasterOn: false, services: services)
        let advisories = eligibility.advisories.filter(showsInWelcome)
        // No surface records the largest grant macOS gave yet, so the sentence quotes the limit alone.
        let text = VerdictText.make(eligibility.verdict, advisories: advisories, lastGrant: nil, capMode: card.capMode,
                                    oledIdleMinutes: idleMinutes, in: language)
        return WelcomeDisplayRow(key: facts.ref.key, name: facts.name, isBuiltIn: facts.isBuiltIn,
                                 verdict: eligibility.verdict, advisories: advisories, capMode: card.capMode, text: text,
                                 canBoost: card.canBoost, storedBoostEnabled: card.boostEnabled,
                                 boostEnabled: choice ?? card.boostEnabled, isOLED: card.isOLED,
                                 top: card.canBoost ? card.top : 1, fix: Fix(text.fix))
    }

    /// The advisories step 2 shows as a second line under the verdict (DESIGN.md §12.1): OLED care. "Keep
    /// Automatically adjust brightness…" is Settings only (§7.4), and the calibration note is left out because
    /// calibration is not part of Welcome (§8): on a first run it would repeat on every row.
    static func showsInWelcome(_ advisory: Advisory) -> Bool {
        switch advisory {
        case .oledCare: true
        case .autoBrightnessInteracts, .notCalibrated: false
        }
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
