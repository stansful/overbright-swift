// OverbrightPanelUITests/HelpAnchorTests.swift — the local Help window's answers and anchors (DESIGN.md §12.6): every
// anchor of the design exists once, in order, with a question and an answer; an unknown anchor opens at the top; the
// "Learn more" links of chips and the "Why?" rows point at real anchors; answer 3 names the live Back to Standard
// shortcut and has the variant without it (§16: key caps are never typed into copy).
import OverbrightCore
import SwiftUI
import Testing
@testable import OverbrightPanelUI

@MainActor @Suite struct HelpAnchorTests {
    /// DESIGN.md §12.6's anchors, in order.
    static let designAnchors = ["no-extra-range", "washed-out", "back-to-standard", "looks-wrong", "limited",
                                "brightness-keys", "battery", "menu-bar-icon", "control-center"]

    @Test func everyAnchorOfTheDesignHasOneAnswerInOrder() {
        let entries = HelpEntry.all(backToStandardKeys: "⌃⌥⌘0")
        #expect(entries.map(\.id) == Self.designAnchors)
        #expect(HelpEntry.Anchor.all == Self.designAnchors)
        for entry in entries {
            #expect(!entry.question.isEmpty && !entry.answer.isEmpty, "\(entry.id)")
        }
    }

    @Test func knownAnchorsResolveAndUnknownOnesOpenAtTheTop() {
        for anchor in Self.designAnchors { #expect(HelpView.resolve(anchor) == anchor) }
        #expect(HelpView.resolve(nil) == nil)
        #expect(HelpView.resolve("no-such-answer") == nil)
        #expect(HelpView(anchor: "control-center").resolvedAnchor == "control-center")
        #expect(HelpView(anchor: "bogus").resolvedAnchor == nil)
    }

    @Test func learnMoreLinksPointAtRealAnchors() throws {
        let services = try #require(ScriptedStatuses.services(named: "no-extra-range"))
        let failed = try #require(services.boost.status.displays.first)
        let card = DisplayCardModel(status: failed, isMasterOn: true, services: services)
        let anchors = CardChip.kinds(for: card, isMasterOn: true).compactMap { action -> String? in
            if case .learnMore(let anchor) = action { return anchor }
            return nil
        }
        #expect(anchors == [HelpEntry.Anchor.noExtraRange])
        for anchor in anchors { #expect(HelpView.resolve(anchor) == anchor) }
    }

    @Test func answerThreeUsesTheLiveShortcutOrLeavesItOut() throws {
        let with = try #require(HelpEntry.all(backToStandardKeys: "⌃⌥⌘0").first { $0.id == "back-to-standard" })
        let without = try #require(HelpEntry.all(backToStandardKeys: nil).first { $0.id == "back-to-standard" })
        #expect(with.answer.contains("⌃⌥⌘0"))
        #expect(!without.answer.contains("⌃⌥⌘"))
        #expect(with.answer != without.answer)
        let german = try #require(HelpEntry.all(backToStandardKeys: "⌃⌥⌘ß").first { $0.id == "back-to-standard" })
        #expect(german.answer.contains("⌃⌥⌘ß"))                              // whatever the layout renders
    }

    @Test func helpOpensAtTheAnchorWithoutAWindow() {
        let view = HelpView(anchor: "battery", backToStandardKeys: nil)
        #expect(view.entries.count == Self.designAnchors.count)
        #expect(view.resolvedAnchor == "battery")
    }
}
