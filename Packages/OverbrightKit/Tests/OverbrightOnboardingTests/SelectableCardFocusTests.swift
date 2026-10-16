// OverbrightOnboardingTests/SelectableCardFocusTests.swift — keyboard focus is visible on every login option card of
// step 3, the selected one included (DESIGN.md §5.12, §15; WCAG 2.4.7; WP14 C-ONBOARD-2): the concentric focus ring
// sits `Radius.focusRingOutset` outside the card, so it shows next to the selected card's own ring. Measured on the
// rendered card: the pixels of the outset band change with focus, the selection ring on the card's edge does not.
// Rendered in-process in a window that is never ordered in.
import AppKit
import OverbrightDesign
import SwiftUI
import Testing
@testable import OverbrightOnboarding

@MainActor @Suite struct SelectableCardFocusTests {
    /// The card's size and the margin around it in the rendering (room for the outset ring).
    static let card = CGSize(width: 160, height: 56)
    static let margin = Space.l

    /// One card, selected or not, focused or not, in Light.
    static func render(selected: Bool, focused: Bool) throws -> NSBitmapImageRep {
        let view = SelectableCard(isSelected: selected, isFocused: focused) {
            Text(verbatim: "Open, keep off").padding(Space.m)
        }
        .frame(width: card.width, height: card.height)
        .padding(margin)
        return try ChromeSnapshot.render(view, .light,
                                         size: CGSize(width: card.width + 2 * margin, height: card.height + 2 * margin))
    }

    /// The colour at `x` points from the card's leading edge (negative: outside it), half way down the card.
    static func color(_ rep: NSBitmapImageRep, atEdgeOffset x: CGFloat) -> NSColor? {
        let scale = CGFloat(rep.pixelsWide) / rep.size.width
        return rep.colorAt(x: Int(((margin + x) * scale).rounded(.down)),
                           y: Int(((margin + card.height / 2) * scale).rounded(.down)))
    }

    /// The largest difference of one RGB component between two colours.
    static func distance(_ a: NSColor?, _ b: NSColor?) -> CGFloat {
        guard let a = a?.usingColorSpace(.deviceRGB), let b = b?.usingColorSpace(.deviceRGB) else { return 0 }
        return max(abs(a.redComponent - b.redComponent), abs(a.greenComponent - b.greenComponent),
                   abs(a.blueComponent - b.blueComponent))
    }

    @Test func focusShowsOnTheSelectedCardToo() throws {
        let keyboard = KeyboardInteraction.shared
        let wasActive = keyboard.isActive
        keyboard.record(isKey: true)                                              // focus rings follow keyboard use
        defer { keyboard.record(isKey: wasActive) }

        let band = -(Radius.focusRingOutset - StrokeWidth.focusRing / 2)          // inside the 2-pt outset ring
        let edge = StrokeWidth.focusRing / 2                                      // inside the selection ring
        for selected in [true, false] {
            let focused = try Self.render(selected: selected, focused: true)
            let unfocused = try Self.render(selected: selected, focused: false)
            let background = unfocused.colorAt(x: 1, y: 1)
            #expect(Self.distance(Self.color(unfocused, atEdgeOffset: band), background) < 0.02,
                    "selected \(selected): nothing outside the card without focus")
            #expect(Self.distance(Self.color(focused, atEdgeOffset: band), background) > 0.15,
                    "selected \(selected): the focus ring shows outside the card")
            #expect(focused.representation(using: .png, properties: [:])
                    != unfocused.representation(using: .png, properties: [:]), "selected \(selected)")
            try ChromeSnapshot.write(focused, "login-card-\(selected ? "selected" : "unselected")-focused", .light)
        }
        let selected = try Self.render(selected: true, focused: false)
        let unselected = try Self.render(selected: false, focused: false)
        #expect(Self.distance(Self.color(selected, atEdgeOffset: edge), Self.color(unselected, atEdgeOffset: edge)) > 0.15,
                "the selection ring on the card's edge")
    }

    /// Without keyboard use (a click), focus draws no ring (DESIGN.md §5.12), as everywhere else in Overbright.
    @Test func aClickDrawsNoRing() {
        #expect(!OverbrightFocusRing.showsRing(isFocused: true, keyboardActive: false))
        #expect(OverbrightFocusRing.ringRadius(for: WelcomeMetrics.cardRadius)
                == WelcomeMetrics.cardRadius + Radius.focusRingOutset)            // concentric with the card
    }
}
