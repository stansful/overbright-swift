// OverbrightIntents/Router/IntentRouter+Reports.swift — what the router tells the Shortcuts app: Get Overbright
// State's dialog and the displays the `DisplayQuery` offers. DESIGN.md §12.8, §1 principle 4; ARCHITECTURE.md §7.7;
// D8 (names for presentation only).
//
// The dialog uses the panel's own value text: the adapter passes Design's builder (`ValueText.make`), which this L1
// module cannot import, so every surface says a level with the same words (byte-identical, principle 4).
import Foundation
import OverbrightCore
import OverbrightPolicy

extension IntentRouter {
    /// Get Overbright State: on or off and, while on, each display's value text, e.g. "Overbright is on. Built-in
    /// Display: Bright room · ×1.29. MPG322UX OLED: Dimmed · 25 %." Displays that can neither boost nor dim are not
    /// named, nor are displays whose value text is empty.
    public func stateReport(valueText: (ReadoutValues) -> String) async throws -> StateReport {
        let status = try await ready().status
        guard status.isOn else {
            return StateReport(isOn: false, dialog: String(localized: "Overbright is off.", bundle: .module,
                                                           comment: "Shortcuts app: Get Overbright State’s answer while Overbright is off."))
        }
        var sentences = [String(localized: "Overbright is on.", bundle: .module,
                                comment: "Shortcuts app: first sentence of Get Overbright State’s answer while Overbright is on; each display’s level follows.")]
        for display in status.displays where Self.isListed(display) {
            let value = valueText(Readout.values(for: display, isMasterOn: true))
            guard !value.isEmpty else { continue }
            let name = Self.isolated(display.name)
            sentences.append(String(localized: "\(name): \(value).", bundle: .module,
                                    comment: "Shortcuts app: one display in Get Overbright State’s answer. %1$@ = the display’s name, %2$@ = its level as the panel shows it (“Bright room · ×1.29”, “Dimmed · 25 %”)."))
        }
        return StateReport(isOn: true, dialog: sentences.joined(separator: " "))
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

    /// `name` between first-strong and pop directional isolates, so a right-to-left name keeps the sentence's order.
    static func isolated(_ name: String) -> String { "\u{2068}\(name)\u{2069}" }
}
