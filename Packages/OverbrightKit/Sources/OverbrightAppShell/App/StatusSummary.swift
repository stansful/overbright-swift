// OverbrightAppShell/App/StatusSummary.swift — DEBUG-only: what the menu bar symbol, the panel's banner and each card's
// chip show now, in English, plus the ports' counters (`dump` in a scenario, `--qa-status <file>`; ARCHITECTURE.md
// §8.5, §10.15). The chip is chosen exactly as the panel chooses it (`CardChip`), and its words and the banner's are
// Design's (`ChipModel`, `BannerModel`), so a scenario checks the copy end to end, not only the reasons. A reason
// names a conflicting app by its catalogue entry and severity only; under `--qa-live-signals`, whose real probe reports
// apps that run on this Mac, the banner and the chips do too, and a listed app's bundle ID is dropped (§9.2 rule 8).
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

    /// The summary of `services` now; `namingAppsByEntry` names every app the way `byEntry(_:)` does (the real
    /// Signals of `--qa-live-signals`).
    static func of(_ services: OverbrightServices, gamma: any GammaPort, triggers: any TriggerFactory,
                   label: String, namingAppsByEntry: Bool = false) -> StatusSummary {
        let status = namingAppsByEntry ? byEntry(services.boost.status) : services.boost.status
        let english = CopyLanguage.english()
        let roles = Dictionary(ScenarioScript.displays.map { ($0.value, $0.key) }) { first, _ in first }
        let displays = status.displays.map { display -> Display in
            let reason = CardChip.reason(decision: display.decision, key: display.key, banner: status.banner,
                                         isMasterOn: status.isOn)
            let context = ChipContext.of(display, facts: services.displays.facts(for: display.key), language: english)
            let card = !PanelContent.isNonCapable(display)
            let chip = card ? ChipModel.make(reason: reason, phase: status.isOn ? display.phase : .idle,
                                             failedTries: display.failedTries, context: context) : nil
            return Display(display: roles[display.key] ?? display.key.rawValue, phase: text(display.phase),
                           target: target(display.decision?.target), applied: (display.appliedGain * 100).rounded() / 100,
                           card: card, chip: chip?.text,
                           reasons: (display.decision?.reasons ?? []).map(text))
        }
        let titles = CardTitles.titles(for: status.displays)
        let banner = status.banner.map { BannerModel.make($0, displayNames: titles, in: english).sentence }
        return StatusSummary(label: label, isOn: status.isOn, symbol: status.symbol.rawValue, banner: banner,
                             displays: displays, gammaWrites: gamma.writeCount, triggerWindows: triggers.openWindowCount)
    }

    /// One JSON line (sorted keys).
    var jsonLine: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(self)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    /// A reason as the dump writes it: a conflicting app by its catalogue entry and severity, never its name, bundle
    /// ID or process.
    static func text(_ reason: LimitReason) -> String {
        switch reason {
        case .conflict(let app): "conflict(\(entry(app)))"
        case .tripped(.attributedDrift(let app)): "tripped(attributedDrift(\(entry(app))))"
        default: String(describing: reason)
        }
    }

    /// A phase as the dump writes it: a drift trip names its app as `text(_:)` does.
    static func text(_ phase: EnginePhase) -> String {
        if case .failed(.attributedDrift(let app)) = phase { return "failed(attributedDrift(\(entry(app))))" }
        return String(describing: phase)
    }

    private static func entry(_ app: ConflictingApp) -> String { "\(app.entryID), \(app.severity.rawValue)" }

    /// `status` with every conflicting app named by its catalogue entry (its name is the entry ID; no bundle ID, no
    /// process) and every listed app's bundle ID replaced by `listedApp`, so the banner, the chips, the reasons and a
    /// drift trip's phase name no app that runs on this Mac.
    static func byEntry(_ status: BoostStatus) -> BoostStatus {
        func app(_ app: ConflictingApp) -> ConflictingApp {
            ConflictingApp(entryID: app.entryID, severity: app.severity, bundleID: nil, processID: 0,
                           displayName: app.entryID)
        }
        func reason(_ reason: LimitReason) -> LimitReason {
            switch reason {
            case .conflict(let found): .conflict(app(found))
            case .tripped(.attributedDrift(let found)): .tripped(.attributedDrift(app(found)))
            case .pausedApp: .pausedApp(bundleID: listedApp)
            default: reason
            }
        }
        var status = status
        switch status.banner {
        case .conflict(let found)?: status.banner = .conflict(app(found))
        case .attributedDrift(let found, let display)?: status.banner = .attributedDrift(app(found), display: display)
        default: break
        }
        for index in status.displays.indices {
            if let reasons = status.displays[index].decision?.reasons {
                status.displays[index].decision?.reasons = reasons.map(reason)
            }
            if case .failed(.attributedDrift(let found)) = status.displays[index].phase {
                status.displays[index].phase = .failed(.attributedDrift(app(found)))
            }
        }
        return status
    }

    /// What `byEntry(_:)` puts in place of a listed app's bundle ID.
    static let listedApp = "listed-app"

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
