// OverbrightIntents/Router/IntentRouter+Reports.swift — what the router tells the Shortcuts app: Get Overbright
// State's dialog and the displays the `DisplayQuery` offers. DESIGN.md §12.8, §1 principle 4; ARCHITECTURE.md §7.7;
// D8 (names for presentation only).
//
// The dialog uses the panel's own value text: the adapter passes Design's builder (`ValueText.make`), which this L1
// module cannot import, so every surface says a level with the same words (byte-identical, principle 4). Its sentences
// are joined by the catalog's two-sentence joiner, so languages that write no space between sentences (ja, zh) get none.
import Foundation
import OverbrightCore
import OverbrightPolicy

extension IntentRouter {
    /// Get Overbright State: on or off and, while on, each display's value text, e.g. "Overbright is on. Built-in
    /// Display: Bright room · ×1.29. MPG322UX OLED: Dimmed · 25 %." Displays that can neither boost nor dim are not
    /// named, nor are displays whose value text is empty.
    public func stateReport(valueText: (ReadoutValues) -> String) async throws -> StateReport {
        try await stateReport(valueText: valueText, bundle: .module)
    }

    /// `stateReport(valueText:)` in the language of `bundle` (the module's, or one of its `.lproj` folders in tests).
    func stateReport(valueText: (ReadoutValues) -> String, bundle: Bundle) async throws -> StateReport {
        let status = try await ready().status
        guard status.isOn else {
            return StateReport(isOn: false, dialog: String(localized: "Overbright is off.", bundle: bundle,
                                                           comment: "Shortcuts app: Get Overbright State’s answer while Overbright is off."))
        }
        var sentences = [String(localized: "Overbright is on.", bundle: bundle,
                                comment: "Shortcuts app: first sentence of Get Overbright State’s answer while Overbright is on; each display’s level follows.")]
        for display in status.displays where Self.isListed(display) {
            let value = valueText(Readout.values(for: display, isMasterOn: true))
            guard !value.isEmpty else { continue }
            let name = Self.isolated(display.name)
            sentences.append(String(localized: "\(name): \(value).", bundle: bundle,
                                    comment: "Shortcuts app: one display in Get Overbright State’s answer. %1$@ = the display’s name, %2$@ = its level as the panel shows it (“Bright room · ×1.29”, “Dimmed · 25 %”)."))
        }
        return StateReport(isOn: true, dialog: Self.joined(sentences, bundle: bundle))
    }

    /// The displays the Shortcuts app offers: every online display that can boost or dim (or whose verdict is not
    /// known yet), built-in first, with its name.
    public func displayChoices() async throws -> [DisplayChoice] {
        let boost = try await ready()
        let statuses = Dictionary(boost.status.displays.map { ($0.key, $0) }) { first, _ in first }
        return (displays?.displays ?? []).compactMap { facts in
            if let status = statuses[facts.ref.key], !Self.isListed(status) { return nil }
            return DisplayChoice(key: facts.ref.key, name: facts.name)
        }
    }

    /// A choice for every key, in order: named while online, without a name otherwise (a saved shortcut whose display
    /// is not connected still resolves, so running it reports "That display isn’t connected.").
    public func displayChoices(for keys: [DisplayKey]) async throws -> [DisplayChoice] {
        _ = try await ready()
        return keys.map { DisplayChoice(key: $0, name: displays?.facts(for: $0)?.name) }
    }

    // MARK: Private

    /// Whether a display has a card: it can boost or dim, or its verdict is not known yet.
    static func isListed(_ status: DisplayStatus) -> Bool {
        guard let verdict = knownVerdict(status) else { return true }
        return verdict.allowsBoost || verdict.allowsDim
    }

    /// `sentences` one after the other, each pair joined the way the language writes two sentences (a space in most;
    /// none in Japanese and Chinese, whose sentences end in "。").
    static func joined(_ sentences: [String], bundle: Bundle = .module) -> String {
        sentences.dropFirst().reduce(sentences.first ?? "") { text, next in
            String(localized: "\(text) \(next)", bundle: bundle,
                   comment: "Shortcuts app: joins two sentences of Get Overbright State’s answer; keep or drop the space as your language writes it")
        }
    }

    /// `name` between first-strong and pop directional isolates, so a right-to-left name keeps the sentence's order.
    static func isolated(_ name: String) -> String { "\u{2068}\(name)\u{2069}" }
}
