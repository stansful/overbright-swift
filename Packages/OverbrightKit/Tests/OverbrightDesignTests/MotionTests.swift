// OverbrightDesignTests/MotionTests.swift — DESIGN.md §3.1–§3.2: every motion kind's curve and duration, nothing
// overshoots when it shrinks or leaves, and Reduce Motion keeps only short cross-fades (no springs, no scales; the
// press scale and the snaps become immediate). ARCHITECTURE.md §10.11 Tests.
import SwiftUI
import Testing
@testable import OverbrightDesign

@Suite struct MotionTests {
    /// The table of DESIGN.md §3.1.
    @Test func theMotionTable() {
        let table: [OverbrightMotion.Kind: OverbrightMotion.Curve] = [
            .panelIn: .easeOut(0.18), .panelOut: .easeIn(0.12), .contentSwap: .smooth(0.25),
            .expand: .spring(duration: 0.30, bounce: 0), .hover: .easeOut(0.12), .press: .spring(duration: 0.18, bounce: 0.2),
            .detentSnap: .spring(duration: 0.20, bounce: 0), .colorShift: .easeInOut(0.40), .hudIn: .easeOut(0.18),
            .hudOut: .easeIn(0.25), .bannerIn: .easeOut(0.22), .bannerOut: .easeIn(0.22),
        ]
        #expect(table.count == OverbrightMotion.Kind.allCases.count)
        for kind in OverbrightMotion.Kind.allCases { #expect(kind.spec == table[kind], "\(kind)") }
    }

    /// Only the press bounces (it grows back); everything that settles, shrinks or leaves has no overshoot.
    @Test func nothingOvershootsWhenItShrinks() {
        for kind in OverbrightMotion.Kind.allCases where kind != .press {
            #expect(kind.spec.bounce == 0, "\(kind)")
        }
        #expect(OverbrightMotion.pressScale == 0.97 && OverbrightMotion.bannerSlide == 6)
    }

    /// Reduce Motion: cross-fades only, at most 0.2 s, never a spring; the press and the snaps are immediate.
    @Test func reduceMotionKeepsShortCrossFades() {
        for kind in OverbrightMotion.Kind.allCases {
            guard let reduced = kind.reducedSpec else {
                #expect([.press, .detentSnap].contains(kind), "\(kind) must still fade")
                continue
            }
            #expect(reduced.duration <= 0.2, "\(kind)")
            if case .spring = reduced { Issue.record("\(kind): a spring under Reduce Motion") }
            #expect(reduced.duration <= kind.spec.duration, "\(kind) gets no slower")
        }
        #expect(OverbrightMotion.Kind.detentSnap.reducedSpec == nil, "the detent snap is immediate")
    }

    @Test func theThemePicksTheVariant() {
        let calm = OverbrightTheme(reduceMotion: true), lively = OverbrightTheme()
        for kind in OverbrightMotion.Kind.allCases {
            #expect(lively.animation(kind) != nil, "\(kind)")
            #expect((calm.animation(kind) == nil) == (kind.reducedSpec == nil), "\(kind)")
        }
        #expect(!calm.animatesSymbols && lively.animatesSymbols)
        #expect(!calm.allowsScale && lively.allowsScale)
    }
}
