// OverbrightPanelUI/Card/CardChip.swift — which reason a card's chip shows, and the actions of its popover.
// ARCHITECTURE.md §6.2, §7.2 (a stop caused by an S1 booster offers Compatibility mode, never Continue anyway, and it
// continues next to the app on that display, as the banner's does);
// DESIGN.md §5.7, §12.2 (actions and their destinations). The words are Design's (`ChipModel.make`); this file decides
// only WHICH reason and WHAT each action does.
import OverbrightCore
import OverbrightDesign

/// The chip line of a display card.
public enum CardChip {
    /// The first per-display reason of `decision` that a chip may show: never a reason that applies to every display
    /// (the banner says those once), never "off" or "shielded", never the trip the banner already names; a display
    /// that can dim but not boost shows its verdict (a neutral chip with the verdict's fix). Nil while the master is
    /// off ("no chips", DESIGN.md §5.11) or when nothing per-display applies. The engine phase ("Preparing…", "No
    /// extra range") is passed to `ChipModel.make` separately and wins there.
    public static func reason(decision: DisplayDecision?, key: DisplayKey, banner: Banner?, isMasterOn: Bool)
        -> LimitReason? {
        guard isMasterOn, let decision else { return nil }
        let shown = decision.reasons.first { reason in
            switch reason {
            case .masterOff, .shielded: return false
            case .tripped(let cause): return !bannerNames(cause, on: key, banner)
            default: return !reason.isGlobal
            }
        }
        if let shown { return shown }
        let verdict = decision.eligibility.verdict
        if !verdict.allowsBoost && verdict.allowsDim { return .notSupported(verdict) }
        return nil
    }

    /// The chip model of a card, nil when it shows none.
    public static func model(for card: DisplayCardModel, isMasterOn: Bool) -> ChipModel? {
        let phase: EnginePhase = isMasterOn ? card.phase : .idle
        return ChipModel.make(reason: card.chipReason, phase: phase, failedTries: card.failedTries)
    }

    /// What the chip's popover offers, in order. `commands` performs them.
    public static func actions(for card: DisplayCardModel, isMasterOn: Bool, commands: PanelCommands) -> [ChipAction] {
        kinds(for: card, isMasterOn: isMasterOn).map { kind in
            ChipAction(title: kind.title) { commands.perform(kind, on: card) }
        }
    }

    /// What the chip's popover offers, without the closures (tests compare these).
    public static func kinds(for card: DisplayCardModel, isMasterOn: Bool) -> [CardAction] {
        if isMasterOn, case .failed(.headroomNeverArrived) = card.phase {
            guard card.failedTries >= 2 else { return [.tryAgain, .learnMore(HelpEntry.Anchor.noExtraRange)] }
            var actions: [CardAction] = [.tryAgain, .runSelfTest]
            if MechanismPreference.overlayIsAvailable, card.advisories.contains(.compatibilityModeAdvised) {
                actions.append(.useCompatibilityMode)
            }
            return actions + [.learnMore(HelpEntry.Anchor.noExtraRange)]
        }
        switch card.chipReason {
        case .boostNotEnabled?: return [.turnOnExtraBrightness]
        case .notSupported(let verdict)?: return verdictFix(verdict).map { [$0] } ?? []
        case .nearFullBrightnessOnly?: return [.changeTaperSetting]
        case .safeLimit?, .oledLimit?: return [.choosePeak]
        case .fullScreenVideo?, .fullScreenApp?, .game?: return [.changeRules]
        case .pausedApp?: return [.editApps]
        case .tripped(.attributedDrift(let app))?:
            return app.severity == .booster
                ? (MechanismPreference.overlayIsAvailable ? [.continueInCompatibilityMode(app)] : [])
                : [.continueAnyway(app)]
        case .tripped(.foreignTableAtLaunch)?: return [.openDisplaySettings]
        case .tripped?: return [.tryAgain]
        default: return []
        }
    }

    /// The fix of a verdict that can be fixed in System Settings (DESIGN.md §12.1).
    public static func verdictFix(_ verdict: DisplayVerdict) -> CardAction? {
        switch verdict {
        case .presetLimits, .turnOnHDR, .switchPreset, .referencePreset: .openDisplaySettings
        default: nil
        }
    }

    /// The banner already names this trip on this display (a card shows no chip for it, §6.2).
    static func bannerNames(_ cause: TripCause, on key: DisplayKey, _ banner: Banner?) -> Bool {
        switch (cause, banner) {
        case (.oscillation, .flickerStop(let display)?): display == key
        case (.repairBudgetExceeded, .unattributedDrift(let display)?): display == key
        case (.attributedDrift, .attributedDrift(_, let display)?): display == key
        case (.foreignTableAtLaunch, .foreignTableAtLaunch?): true
        default: false
        }
    }
}
