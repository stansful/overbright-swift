// OverbrightAppShell/App/StatusSummary.swift — DEBUG-only: what the menu bar symbol, the panel's banner and each card's
// chip show now, in English, plus the ports' counters (`dump` in a scenario, `--qa-status <file>`; ARCHITECTURE.md
// §8.5, §10.15). The chip is chosen exactly as the panel chooses it (`CardChip`), and its words and the banner's are
// Design's (`ChipModel`, `BannerModel`), so a scenario checks the copy end to end, not only the reasons.
#if DEBUG
import Foundation
import OverbrightCore
import OverbrightDesign
import OverbrightPanelUI

/// One snapshot of what Overbright shows.
struct StatusSummary: Equatable, Codable {
    /// What one display card shows.
    struct Display: Equatable, Codable {
        /// The fixture role ("built-in", "msi") or the display key.
        var display: String
        /// The engine phase ("boosted", "gating(rung: 2)").
        var phase: String
        /// The decision's target ("boost ×1.29", "dim 25 %", "neutral").
        var target: String
        /// The light gain on screen (1 = Standard).
        var applied: Double
        /// The display has a card (it can boost or dim); otherwise it sits in the "Why?" row and shows no chip.
        var card: Bool
        /// The chip's English text, nil without a chip.
        var chip: String?
        /// The decision's reasons, in precedence order.
        var reasons: [String]
    }

    /// The scenario's label.
    var label: String
    /// The master switch.
    var isOn: Bool
    /// The menu bar symbol.
    var symbol: String
    /// The banner's English sentence, nil without one.
    var banner: String?
    /// One entry per online display.
    var displays: [Display]
    /// `GammaPort.writeCount` (the fake's, under `--qa-simulate`).
    var gammaWrites: Int
    /// `TriggerFactory.openWindowCount` (the fake's: nothing is ever ordered in).
    var triggerWindows: Int

    /// The summary of `services` now.
    static func of(_ services: OverbrightServices, gamma: any GammaPort, triggers: any TriggerFactory,
                   label: String) -> StatusSummary {
        let status = services.boost.status
        let english = CopyLanguage.english()
        let roles = Dictionary(ScenarioScript.displays.map { ($0.value, $0.key) }) { first, _ in first }
        let displays = status.displays.map { display -> Display in
            let reason = CardChip.reason(decision: display.decision, key: display.key, banner: status.banner,
                                         isMasterOn: status.isOn)
            let context = ChipContext.of(display, facts: services.displays.facts(for: display.key), language: english)
            let card = !PanelContent.isNonCapable(display)
            let chip = card ? ChipModel.make(reason: reason, phase: status.isOn ? display.phase : .idle,
                                             failedTries: display.failedTries, context: context) : nil
            return Display(display: roles[display.key] ?? display.key.rawValue, phase: String(describing: display.phase),
                           target: target(display.decision?.target), applied: (display.appliedGain * 100).rounded() / 100,
                           card: card, chip: chip?.text,
                           reasons: (display.decision?.reasons ?? []).map { String(describing: $0) })
        }
        let banner = status.banner.map { BannerModel.make($0, displayNames: [:], in: english).sentence }
        return StatusSummary(label: label, isOn: status.isOn, symbol: status.symbol.rawValue, banner: banner,
                             displays: displays, gammaWrites: gamma.writeCount, triggerWindows: triggers.openWindowCount)
    }

    /// One JSON line (sorted keys).
    var jsonLine: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(self)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    private static func target(_ target: BoostTarget?) -> String {
        switch target {
        case .boost(let gain)?: String(format: "boost ×%.2f", gain)
        case .dim(let light)?: String(format: "dim %.0f %%", light * 100)
        case .neutral?: "neutral"
        case nil: "none"
        }
    }
}
#endif
