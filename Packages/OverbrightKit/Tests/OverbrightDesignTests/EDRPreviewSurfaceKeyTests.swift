// OverbrightDesignTests/EDRPreviewSurfaceKeyTests.swift — the Welcome card's divider has a key path (DESIGN.md §8,
// §15 "every action has a key path"): the card is one focusable element, and ← / → move the divider by 10 % toward the
// side they point at, mirrored right to left like the level slider's keys, clamped at the card's edges. The card is the
// SDR stand-in in a window that is never ordered in; key events are handed to that window, never posted.
import AppKit
import OverbrightTestSupport
import SwiftUI
import Testing
@testable import OverbrightDesign

@MainActor @Suite struct EDRPreviewSurfaceKeyTests {
    /// The divider as the card last drew it (reported after each update, like the Welcome step's own state).
    final class Shown {
        var divider = 0.5
    }

    @Test func arrowsStepTheDividerTowardTheSideTheyPointAt() {
        func next(_ key: KeyEquivalent, _ from: Double, _ direction: LayoutDirection = .leftToRight) -> Double? {
            EDRPreviewSurface.divider(after: key, from: from, direction: direction)
        }
        #expect(next(.rightArrow, 0.5).map { abs($0 - 0.6) < 1e-9 } == true)
        #expect(next(.leftArrow, 0.5).map { abs($0 - 0.4) < 1e-9 } == true)
        // Right to left the divider is measured from the right edge: → moves it right, toward the leading edge.
        #expect(next(.rightArrow, 0.5, .rightToLeft).map { abs($0 - 0.4) < 1e-9 } == true)
        #expect(next(.leftArrow, 0.5, .rightToLeft).map { abs($0 - 0.6) < 1e-9 } == true)
        #expect(next(.rightArrow, 0.95) == 1, "clamped at the trailing edge")
        #expect(next(.leftArrow, 0.05) == 0, "clamped at the leading edge")
        #expect(next(.upArrow, 0.5) == nil && next(.home, 0.5) == nil, "other keys are left to the window")
    }

    /// Focused, the card takes → and ←: the divider moves 10 % per press, and right to left → moves it the other way
    /// along its binding (toward the right edge, where the layout starts).
    @Test(arguments: [LayoutDirection.leftToRight, .rightToLeft])
    func theFocusedCardMovesTheDividerWithTheArrows(direction: LayoutDirection) async throws {
        let shown = Shown()
        let hosted = HostedView(CardHost(shown: shown), size: CGSize(width: 320, height: 200), direction: direction)
        defer { hosted.close() }
        hosted.window.makeKey()
        #expect(await eventually { hosted.hostIsFirstResponder }, "the card's window gave SwiftUI the keys")
        // The card asks for focus when it appears, and a press before SwiftUI has granted it is ignored: press until
        // the divider has moved (checked before each press, so it moves once).
        #expect(await eventually {
            if shown.divider != 0.5 { return true }
            try? hosted.press(.rightArrow)
            return false
        }, "\(direction): → moved the divider")
        let (raised, lowered) = direction == .leftToRight ? (0.6, 0.4) : (0.4, 0.6)
        #expect(abs(shown.divider - raised) < 1e-9, "\(direction): one step, \(shown.divider)")
        try hosted.press(.leftArrow)
        #expect(await eventually { abs(shown.divider - 0.5) < 1e-9 }, "\(direction): ← moved it back")
        try hosted.press(.leftArrow)
        #expect(await eventually { abs(shown.divider - lowered) < 1e-9 }, "\(direction): and on, \(shown.divider)")
    }
}

/// The card over its own state, as the Welcome step holds it, focused as it appears; reports the divider it draws.
private struct CardHost: View {
    let shown: EDRPreviewSurfaceKeyTests.Shown
    @State private var divider = 0.5

    var body: some View {
        EDRPreviewSurface(gain: 1.29, divider: $divider, simulated: true)
            .focusedOnAppear()
            .frame(width: 300, height: 180)
            .onChange(of: divider) { _, value in shown.divider = value }
    }
}
