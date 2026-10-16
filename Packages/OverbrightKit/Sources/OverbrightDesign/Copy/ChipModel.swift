// OverbrightDesign/Copy/ChipModel.swift — what one status chip shows. DESIGN.md §5.7, §12.2; ARCHITECTURE.md §6.2.
// Seam written by WP0a (ARCHITECTURE.md §10.0): the type and `make(reason:phase:failedTries:)` are fixed; WP9 writes
// the copy and the mapping of every `LimitReason` and engine phase. A chip appears only for a per-display reason;
// reasons that apply to every display are the banner's, said once.
import Foundation
import OverbrightCore

/// A per-display status chip: glyph, short text and the one-sentence explanation of its popover.
public nonisolated struct ChipModel: Hashable, Sendable {
    /// The glyph.
    public var symbol: OverbrightSymbol
    /// The glyph colour and the tint behind the text.
    public var color: SemanticColor
    /// The chip text ("Limited by macOS"), already localized.
    public var text: String
    /// The popover sentence, already localized.
    public var explanation: String
    /// The VoiceOver label (the full text when `text` is truncated, e.g. a long app name).
    public var accessibilityLabel: String
    /// A small progress indicator replaces the glyph ("Preparing…").
    public var showsProgress: Bool
    /// The popover's actions, in order (also VoiceOver actions on the card).
    public var actions: [FixAction]
    /// The Help answer "Learn more" opens.
    public var helpAnchor: String?

    /// A chip.
    public init(symbol: OverbrightSymbol, color: SemanticColor, text: String, explanation: String,
                accessibilityLabel: String) {
        self.init(symbol: symbol, color: color, text: text, explanation: explanation,
                  accessibilityLabel: accessibilityLabel, showsProgress: false, actions: [], helpAnchor: nil)
    }

    /// A chip with its progress indicator, actions and Help anchor.
    public init(symbol: OverbrightSymbol, color: SemanticColor, text: String, explanation: String,
                accessibilityLabel: String, showsProgress: Bool, actions: [FixAction], helpAnchor: String?) {
        self.symbol = symbol; self.color = color; self.text = text; self.explanation = explanation
        self.accessibilityLabel = accessibilityLabel; self.showsProgress = showsProgress; self.actions = actions
        self.helpAnchor = helpAnchor
    }

    /// The Help anchor of "The screen didn't get brighter" (DESIGN.md §12.6).
    public static let noExtraRangeAnchor = "no-extra-range"

    /// The chip of a display: "Preparing…" and "No extra range" come from the engine phase and win while they apply,
    /// else the first per-display reason in policy order; nil when nothing per-display applies (global reasons are the
    /// banner's). `failedTries` changes the "No extra range" chip after two tries (DESIGN.md §12.2).
    public static func make(reason: LimitReason?, phase: EnginePhase, failedTries: Int) -> ChipModel? {
        make(reason: reason, phase: phase, failedTries: failedTries, context: ChipContext())
    }

    /// `make(reason:phase:failedTries:)` with the numbers and names the sentences quote.
    public static func make(reason: LimitReason?, phase: EnginePhase, failedTries: Int,
                            context: ChipContext) -> ChipModel? {
        switch phase {
        case .arming, .gating: return preparing(in: context.language)
        case .failed(.headroomNeverArrived): return noExtraRange(failedTries: failedTries, context: context)
        default: break
        }
        guard let reason else { return nil }
        return ChipCopy.chip(for: reason, failedTries: failedTries, context: context)
    }

    /// The chip of `status` while `banner` shows: the phase chip, else the first reason of its decision that is
    /// per-display and not the banner's own, else, on a display that can dim but not boost, its verdict badge.
    public static func make(for status: DisplayStatus, banner: Banner?, context: ChipContext) -> ChipModel? {
        let reason = chipReason(in: status.decision?.reasons ?? [], display: status.key, banner: banner)
        if let chip = make(reason: reason, phase: status.phase, failedTries: status.failedTries, context: context) {
            return chip
        }
        guard let verdict = status.decision?.eligibility.verdict, !verdict.allowsBoost, verdict.allowsDim else { return nil }
        return Self.verdict(verdict, in: context.language)
    }

    /// The verdict badge of a display that can dim but not boost, as a neutral chip whose popover holds the verdict's
    /// sentence and fix (DESIGN.md §5.10, §12.2).
    public static func verdict(_ verdict: DisplayVerdict, in language: CopyLanguage = .app) -> ChipModel? {
        ChipCopy.chip(for: .notSupported(verdict), failedTries: 0, context: ChipContext(language: language))
    }

    /// The reason a card's chip shows: the first per-display reason (`isGlobal == false`) that has a chip and is not
    /// the one `banner` already says for `display` (a trip on that display, DESIGN.md §12.2).
    public static func chipReason(in reasons: [LimitReason], display: DisplayKey, banner: Banner?) -> LimitReason? {
        reasons.first { reason in
            !reason.isGlobal && ChipCopy.hasChip(reason) && !Self.banner(banner, says: reason, on: display)
        }
    }

    /// "Preparing…" with a progress indicator.
    public static func preparing(in language: CopyLanguage = .app) -> ChipModel {
        let text = CommonNames.preparing(in: language)
        let explanation = String(localized: "Overbright is unlocking extra range on this display. The first time takes a few seconds.",
                                 bundle: language.bundle, locale: language.locale,
                                 comment: "Panel ▸ Display card: popover of the Preparing… chip")
        return ChipModel(symbol: .hourglass, color: .info, text: text, explanation: explanation, accessibilityLabel: text,
                         showsProgress: true, actions: [], helpAnchor: nil)
    }

    /// "No extra range": the ladder found no headroom; after two tries the popover offers more.
    public static func noExtraRange(failedTries: Int, context: ChipContext) -> ChipModel {
        let (b, l) = (context.language.bundle, context.language.locale)
        let text = String(localized: "No extra range", bundle: b, locale: l,
                          comment: "Panel ▸ Display card: status chip when macOS gave no extra range")
        if failedTries >= 2 {
            let explanation = String(localized: "macOS still didn’t make extra range available.", bundle: b, locale: l,
                                     comment: "Panel ▸ Display card: popover of No extra range after two tries")
            var actions: [FixAction] = [.tryAgain, .runSelfTest]
            if context.compatibilityAdvised { actions.append(.useCompatibilityMode) }
            actions.append(.learnMore)
            return ChipModel(symbol: .exclamationMarkTriangleFill, color: .danger, text: text, explanation: explanation,
                             accessibilityLabel: text, showsProgress: false, actions: actions,
                             helpAnchor: noExtraRangeAnchor)
        }
        let explanation = String(localized: "macOS didn’t make extra range available. This can happen right after waking up, or when HDR is off.",
                                 bundle: b, locale: l, comment: "Panel ▸ Display card: popover of No extra range")
        return ChipModel(symbol: .exclamationMarkTriangleFill, color: .danger, text: text, explanation: explanation,
                         accessibilityLabel: text, showsProgress: false, actions: [.tryAgain, .learnMore],
                         helpAnchor: noExtraRangeAnchor)
    }

    /// Whether `banner` is the banner of `reason` on `display` (then the card shows no chip for it).
    private static func banner(_ banner: Banner?, says reason: LimitReason, on display: DisplayKey) -> Bool {
        guard case let .tripped(cause) = reason, let banner else { return false }
        switch (banner, cause) {
        case (.flickerStop(let key), .oscillation), (.unattributedDrift(let key), .repairBudgetExceeded): return key == display
        case (.attributedDrift(let app, let key), .attributedDrift(let tripApp)): return key == display && app == tripApp
        case (.foreignTableAtLaunch, .foreignTableAtLaunch): return true
        default: return false
        }
    }
}
